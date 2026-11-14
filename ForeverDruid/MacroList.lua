-- The druid macros Forever Druid can write: what each one is called, the spells it needs, its text
-- and how the Macros settings page groups them. Creating, updating and deleting them is Macros.lua.
--
-- Spell names come from the client, so the macros work in any language.

local _, ns = ...

local M = {}
ns.macros = M

local ICON = 134400 -- question mark: with #showtooltip the macro shows its spell's icon
local MAX_CHARACTER_MACROS = (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS) or 30

local function S(key)
	return ns.SpellName(key)
end

-- Every macro is written so it never depends on your form changing partway through one key
-- press: on Forever's client a /cancelform doesn't reliably take effect before the next line, so
-- "/cancelform" then "/cast <form or caster spell>" could leave you in caster form with the spell
-- not cast. Spells that need caster form use CASTER below: drop the form, and stop there if the
-- game still has you shapeshifted (then the next press casts). That's one press when the client
-- updates at once, two when it doesn't, and never an error spam or a stray form change.

-- Drop your form for a caster spell (never while prowling), and stop if you're still shifted.
local CASTER = "/cancelform [form,nostealth]\n/stopmacro [form]\n"

-- Your stance-bar number for a form ("cat", "bear"), which depends on which forms you know.
local function FormIndex(form)
	for _, f in ipairs(ns.ShapeshiftForms()) do
		if f.form == form then
			return f.index
		end
	end
end
M.FormIndex = FormIndex

-- The forms each kind of caster spell still works in on Forever, from the spell's shapeshift mask
-- in the client data: heals in Tree of Life; buffs, Innervate, resurrection and cleanses in Moonkin
-- Form and Tree of Life; Balance spells in Moonkin Form. Anything else needs caster form.
local CAN_CAST_IN = {
	heal = { tree = true },
	buff = { moonkin = true, tree = true },
	balance = { moonkin = true },
	none = {},
}

-- Drops only the forms that block this kind of spell (never while prowling), and stops if you're
-- still in one so the cast comes on the next press rather than failing. Before the stance bar has
-- loaded it drops any form, which is never wrong, and the macro is rewritten once it loads.
local function Drop(kind)
	local forms = ns.ShapeshiftForms()
	if #forms == 0 then
		return CASTER
	end
	local allowed, block = CAN_CAST_IN[kind] or CAN_CAST_IN.none, {}
	for _, f in ipairs(forms) do
		if not allowed[f.form] then
			block[#block + 1] = f.index
		end
	end
	if #block == 0 then
		return ""
	end
	local list = table.concat(block, "/")
	return ("/cancelform [form:%s,nostealth]\n/stopmacro [form:%s]\n"):format(list, list)
end
M.Drop = Drop

local function Helpful(spell, kind)
	return ("#showtooltip %s\n" .. Drop(kind) .. "/cast [@mouseover,help,nodead][help,nodead][@player] %s"):format(spell, spell)
end

-- Hold Shift to cast it on your focus (crowd control on a second mob without retargeting).
local function Harmful(spell, kind)
	return ("#showtooltip %s\n" .. Drop(kind) .. "/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] %s"):format(spell, spell)
end

-- Stance-bar numbers for the forms you know among the given ones, as "1/3"; nil if none. "bear"
-- covers Dire Bear Form.
local function Forms(...)
	local wanted, list = {}, {}
	for i = 1, select("#", ...) do
		wanted[select(i, ...)] = true
	end
	for _, f in ipairs(ns.ShapeshiftForms()) do
		if wanted[f.form] then
			list[#list + 1] = f.index
		end
	end
	return #list > 0 and table.concat(list, "/") or nil
end
M.Forms = Forms

-- A Bear attack with Maul queued in the same press (Maul is off the global cooldown and only adds
-- to your next swing), shifting into Bear Form first and stopping there if the shift is pending.
function M.MaulWeave(key)
	local bear = Forms("bear")
	if not bear then
		return nil
	end
	return ("#showtooltip %s\n/cast [noform:%s] !%s\n/stopmacro [noform:%s]\n/startattack\n/cast %s\n/cast %s"):format(
		S(key), bear, S(ns.BearFormKey()), bear, S("maul"), S(key))
end

-- Healing potions and Healthstones, best heal first (Forever client data: the item's spell heal,
-- so Forever's Discolored potions rank above the Classic ones they outheal).
local POTIONS = { 241650, 247242, 223913, 13446, 247241, 3928, 18839, 288896, 223914, 247240, 1710, 287977,
	929, 247239, 268883, 858, 4596, 268882, 287967, 118, 268881, 287966 }
local HEALTHSTONES = { 19013, 9421, 19012, 19011, 5510, 19010, 19009, 5509, 19008, 19007, 5511, 19006, 19005,
	5512, 19004 }
M.POTIONS, M.HEALTHSTONES = POTIONS, HEALTHSTONES

-- The best one in your bags that you can use (not too high a level); nil if none.
local function BestCarried(list)
	if not (C_Item and C_Item.GetItemCount) then
		return nil
	end
	for _, id in ipairs(list) do
		local count = ns.SafeReadable(C_Item.GetItemCount, id)
		if type(count) == "number" and count > 0 then
			local usable = C_Item.IsUsableItem and ns.SafeReadable(C_Item.IsUsableItem, id)
			if usable ~= false then
				return id
			end
		end
	end
	return nil
end
M.BestCarried = BestCarried

local WEAPON = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true }

local function SpiritOf(link)
	local ok, stats = pcall(C_Item.GetItemStats, link)
	if ok and type(stats) == "table" and not ns.IsSecret(stats) then
		local v = stats.ITEM_MOD_SPIRIT_SHORT
		if type(v) == "number" and not ns.IsSecret(v) then
			return v
		end
	end
	return 0
end

-- The main-hand weapon in your bags that scores higher than the one you're wielding; nil if none.
local function BestWeapon(score)
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink
		and C_Item and C_Item.GetItemStats and C_Item.GetItemInfoInstant) then
		return nil
	end
	local worn = GetInventoryItemLink and GetInventoryItemLink("player", 16)
	local best, bestScore = nil, (type(worn) == "string" and score(worn)) or 0
	for bag = 0, 4 do
		local slots = ns.SafeReadable(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (type(slots) == "number" and slots or 0) do
			local link = ns.SafeReadable(C_Container.GetContainerItemLink, bag, slot)
			if type(link) == "string" then
				local ok, id, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, link)
				if ok and type(id) == "number" and WEAPON[equipLoc] then
					local value = score(link)
					if value > bestScore then
						best, bestScore = id, value
					end
				end
			end
		end
	end
	return best
end
local function SpiritWeapon()
	return BestWeapon(SpiritOf)
end
M.SpiritWeapon = SpiritWeapon

-- "/equip" lines for a weapon-swap macro: the swap weapon normally, and with Alt held the weapon
-- (and off-hand) you had on when the macro was written, so one button swaps there and back. Once
-- you're holding the swap weapon nothing in your bags beats it, so the macro stays as written.
local function SwapLines(weapon)
	local id = GetInventoryItemID
	local main = id and ns.SafeReadable(id, "player", 16)
	local off = id and ns.SafeReadable(id, "player", 17)
	if type(main) ~= "number" then
		return ("/equip item:%d\n"):format(weapon)
	end
	local lines = ("/equip [mod:alt] item:%d; item:%d\n"):format(main, weapon)
	if type(off) == "number" then
		lines = lines .. ("/equipslot [mod:alt] 17 item:%d\n"):format(off)
	end
	return lines
end

-- Bear attack power from the item tooltip maths (2 per Strength plus attack power in forms).
function M.BearWeapon()
	return BestWeapon(function(link)
		local v = ns.tooltips and ns.tooltips.Values(link)
		return v and v.bear or 0
	end)
end

-- key, macro name (16 chars max), spells it needs, body builder, what it does. default = false:
-- off until you tick it (the newer, more specialised ones, so they don't fill your macro slots).
-- ready (optional) says what else it needs, such as an item in your bags.
M.LIST = {
	{ key = "rejuv", name = "FD Rejuvenation", renamedFrom = { "FD Rejuv" }, needs = { "rejuvenation" },
		desc = "Rejuvenation on your mouseover, your friendly target, or yourself; hold Shift for Swiftmend once you know it. In a form it drops the form first (press again if it needs a second press).", -- luacheck: no max line length
		body = function()
			if not ns.IsCastable("swiftmend") then
				return Helpful(S("rejuvenation"), "heal")
			end
			return ("#showtooltip\n" .. Drop("heal") .. "/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] %s; [@mouseover,help,nodead][help,nodead][@player] %s"):format( -- luacheck: no max line length
				S("swiftmend"), S("rejuvenation"))
		end },
	{ key = "regrowth", name = "FD Regrowth", needs = { "regrowth" },
		desc = "Regrowth on your mouseover, your friendly target, or yourself, dropping your form first.",
		body = function()
			return Helpful(S("regrowth"), "heal")
		end },
	{ key = "healingTouch", name = "FD Healing Touch", renamedFrom = { "FD Heal Touch" }, needs = { "healingTouch" },
		desc = "Healing Touch on your mouseover, your friendly target, or yourself, dropping your form first.",
		body = function()
			return Helpful(S("healingTouch"), "heal")
		end },
	{ key = "mark", name = "FD Mark", needs = { "markOfTheWild" },
		desc = "Mark of the Wild on your mouseover, your friendly target, or yourself, without changing target; hold Shift for Gift of the Wild once you know it.", -- luacheck: no max line length
		body = function()
			if not ns.IsCastable("giftOfTheWild") then
				return Helpful(S("markOfTheWild"), "buff")
			end
			return ("#showtooltip\n" .. Drop("buff") .. "/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] %s; [@mouseover,help,nodead][help,nodead][@player] %s"):format( -- luacheck: no max line length
				S("giftOfTheWild"), S("markOfTheWild"))
		end },
	{ key = "thorns", name = "FD Thorns", needs = { "thorns" },
		desc = "Thorns on your mouseover, your friendly target, or yourself.",
		body = function()
			return Helpful(S("thorns"), "buff")
		end },
	{ key = "innervate", name = "FD Innervate", needs = { "innervate" },
		desc = "Innervate on your mouseover, your friendly target, or yourself.",
		body = function()
			return Helpful(S("innervate"), "buff")
		end },
	{ key = "rebirth", name = "FD Rebirth", needs = { { "rebirth", "revive" } },
		desc = "Brings back the dead party member under your mouse, or your dead target: Rebirth in combat, Revive (Forever's out-of-combat resurrection) otherwise.", -- luacheck: no max line length
		body = function()
			local rebirth = ns.IsCastable("rebirth") and S("rebirth")
			local revive = ns.IsCastable("revive") and S("revive")
			if rebirth and revive then
				return ("#showtooltip\n" .. Drop("buff") .. "/cast [combat,@mouseover,help,dead][combat,help,dead] %s; [@mouseover,help,dead][help,dead] %s"):format( -- luacheck: no max line length
					rebirth, revive)
			end
			local spell = rebirth or revive
			return ("#showtooltip %s\n" .. Drop("buff") .. "/cast [@mouseover,help,dead][help,dead] %s"):format(spell, spell)
		end },
	{ key = "maul", name = "FD Maul", needs = { "maul" },
		desc = "Maul, making sure you're auto-attacking (Maul only adds to your next swing).",
		body = function()
			return ("#showtooltip %s\n/startattack\n/cast %s"):format(S("maul"), S("maul"))
		end },
	{ key = "claw", name = "FD Claw", needs = { "claw" },
		desc = "Claw, making sure you're auto-attacking.",
		body = function()
			return ("#showtooltip %s\n/startattack\n/cast %s"):format(S("claw"), S("claw"))
		end },
	{ key = "roots", name = "FD Roots", needs = { "entanglingRoots" },
		desc = "Entangling Roots on the enemy under your mouse, or your target; hold Shift for your focus. Drops your form first.",
		body = function()
			return Harmful(S("entanglingRoots"), "none")
		end },
	{ key = "hibernate", name = "FD Hibernate", needs = { "hibernate" },
		desc = "Hibernate on the beast under your mouse, or your target; hold Shift for your focus. Drops your form first (not Moonkin Form).",
		body = function()
			return Harmful(S("hibernate"), "balance")
		end },
	{ key = "shiftCat", name = "FD Cat Form", renamedFrom = { "FD Shift Cat" }, needs = { "catForm" },
		desc = "Into Cat Form from caster or Bear Form, in one press. Never takes you out of Cat Form.",
		body = function()
			return ("#showtooltip %s\n/cast !%s"):format(S("catForm"), S("catForm"))
		end },
	{ key = "shiftBear", name = "FD Bear Form", renamedFrom = { "FD Shift Bear" }, needs = { { "direBearForm", "bearForm" } },
		desc = "Into Bear Form from caster or Cat Form, in one press. Never takes you out of Bear Form.",
		body = function()
			local bear = ns.BearFormKey()
			return ("#showtooltip %s\n/cast !%s"):format(S(bear), S(bear))
		end },
	{ key = "powershift", name = "FD Powershift", needs = { "catForm" },
		desc = "Powershift: leave Cat Form and shift straight back in, for Furor's energy. One press if the game allows it, otherwise press twice (out, then in). Never breaks Prowl.", -- luacheck: no max line length
		body = function()
			local cat = FormIndex("cat")
			if not cat then
				return nil
			end
			return ("#showtooltip %s\n/cancelform [form:%d,nostealth]\n/stopmacro [form:%d]\n/cast !%s"):format(
				S("catForm"), cat, cat, S("catForm"))
		end },
	{ key = "reshift", name = "FD Reshift", needs = { { "catForm", "bearForm", "direBearForm" } }, icon = 132115,
		desc = "Powershift whatever form you're in: Cat back into Cat, Bear back into Bear. One press if the game allows it, otherwise two (out, then back into the same form). Never breaks Prowl.", -- luacheck: no max line length
		body = function()
			return "/click ForeverDruidReshift"
		end },
	{ key = "bearRejuv", name = "FD Bear Rejuv", needs = { { "direBearForm", "bearForm" }, "rejuvenation" },
		desc = "Bear Form, Rejuvenation on yourself (or your mouseover), back into Bear Form: keep pressing the one key. It waits out the global cooldown before shifting back.", -- luacheck: no max line length
		body = function()
			local bear = FormIndex("bear")
			if not bear then
				return nil
			end
			-- Plain "Bear Form" in the sequence: by then you're in caster form, and /castsequence
			-- matches steps by spell ID, which a "!" prefix would break.
			return ("#showtooltip %s\n/cancelform [form:%d]\n/stopmacro [form:%d]\n/castsequence [@mouseover,help,nodead][@player] reset=8 %s, %s"):format(
				S("rejuvenation"), bear, bear, S("rejuvenation"), S(ns.BearFormKey()))
		end },
	{ key = "prowl", name = "FD Prowl", needs = { "catForm", "prowl" },
		desc = "Tap: off your mount and into Cat Form. Tap again: Prowl. Tap while prowling: leave Prowl, staying in Cat Form.",
		body = function()
			local cat = FormIndex("cat")
			if not cat then
				return nil
			end
			return ("#showtooltip %s\n/dismount [mounted]\n/cast [noform:%d] !%s; %s"):format(S("prowl"), cat, S("catForm"), S("prowl"))
		end },
	{ key = "opener", name = "FD Ravage Opener", renamedFrom = { "FD Opener" }, needs = { "catForm", "prowl", "ravage" },
		desc = "Into Cat Form, then Prowl, then Ravage from stealth, then Shred (Claw until you learn Shred) once the fight is on: one key for the whole opener.", -- luacheck: no max line length
		body = function()
			local cat = FormIndex("cat")
			if not cat then
				return nil
			end
			local filler = ns.IsCastable("shred") and S("shred") or (ns.IsCastable("claw") and S("claw"))
			if not filler then
				return ("#showtooltip\n/cast [noform:%d] !%s; [nostealth] %s; %s"):format(cat, S("catForm"), S("prowl"), S("ravage"))
			end
			return ("#showtooltip\n/cast [noform:%d] !%s; [stealth] %s; [nocombat] %s; %s"):format(
				cat, S("catForm"), S("ravage"), S("prowl"), filler)
		end },
	{ key = "faerie", name = "FD Faerie Fire", renamedFrom = { "FD Faerie" }, needs = { { "faerieFireFeral", "faerieFire" } },
		desc = "Faerie Fire on the enemy under your mouse, or your target: the Feral version in Cat or Bear Form, the normal one otherwise.",
		body = function()
			local feral = ns.IsCastable("faerieFireFeral") and S("faerieFireFeral")
			local normal = ns.IsCastable("faerieFire") and S("faerieFire")
			-- Form numbers depend on which forms you've learned, so read them from your stance bar.
			local catBear = {}
			for _, f in ipairs(ns.ShapeshiftForms()) do
				if f.form == "cat" or f.form == "bear" then
					catBear[#catBear + 1] = f.index
				end
			end
			if feral and normal and #catBear > 0 then
				local forms = "form:" .. table.concat(catBear, "/")
				return ("#showtooltip\n/cast [%s,@mouseover,harm,nodead][%s] %s; [@mouseover,harm,nodead][] %s"):format(
					forms, forms, feral, normal)
			end
			return ("#showtooltip\n/cast [@mouseover,harm,nodead][] %s"):format(feral or normal)
		end },
	{ key = "barkskin", name = "FD Barkskin", needs = { "barkskin" },
		desc = "Barkskin, in any form: on Forever it no longer needs caster form.",
		body = function()
			return ("#showtooltip %s\n/cast %s"):format(S("barkskin"), S("barkskin"))
		end },
	{ key = "swiftHeal", name = "FD Swift Heal", needs = { "naturesSwiftness", "healingTouch" },
		desc = "Emergency heal: drops your form, Nature's Swiftness, then an instant Healing Touch on your mouseover, friendly target or yourself.",
		body = function()
			return ("#showtooltip %s\n" .. Drop("heal") .. "/cast %s\n/cast [@mouseover,help,nodead][help,nodead][@player] %s"):format(
				S("naturesSwiftness"), S("naturesSwiftness"), S("healingTouch"))
		end },

	-- Off until ticked (default = false).
	{ key = "growl", name = "FD Growl", needs = { { "direBearForm", "bearForm" }, "growl" }, default = false,
		desc = "Growl on the enemy under your mouse, or your target, without changing target. Out of Bear Form the first press shifts you in.", -- luacheck: no max line length
		body = function()
			local bear = Forms("bear")
			if not bear then
				return nil
			end
			-- Growl is off the global cooldown, so it can follow the shift within one press once the
			-- game has you in Bear Form; until then the second line simply doesn't match.
			return ("#showtooltip %s\n/cast [noform:%s] !%s\n/cast [form:%s,@mouseover,harm,nodead][form:%s] %s"):format(
				S("growl"), bear, S(ns.BearFormKey()), bear, bear, S("growl"))
		end },
	{ key = "lacerate", name = "FD Maul Lacerate", needs = { { "direBearForm", "bearForm" }, "maul", "lacerate" }, default = false,
		desc = "Bear attack: queues Maul on your next swing and casts Lacerate in the same press, with auto-attack on. Out of Bear Form it shifts you in first.", -- luacheck: no max line length
		body = function()
			return M.MaulWeave("lacerate")
		end },
	{ key = "feralCharge", name = "FD Feral Charge", needs = { { "direBearForm", "bearForm" }, "feralCharge" }, default = false,
		desc = "Feral Charge on the enemy under your mouse, or your target: Forever's version charges in Bear Form and leaps behind the target in Cat Form. From caster or another form the first press shifts you into Bear Form.", -- luacheck: no max line length
		body = function()
			local feral, bear = Forms("cat", "bear"), Forms("bear")
			if not (feral and bear) then
				return nil
			end
			return ("#showtooltip %s\n/cast [noform:%s] !%s\n/cast [form:%s,@mouseover,harm,nodead][form:%s] %s"):format(
				S("feralCharge"), feral, S(ns.BearFormKey()), feral, feral, S("feralCharge"))
		end },
	{ key = "dash", name = "FD Dash", needs = { "catForm", "dash" }, default = false,
		desc = "Dash from any form: shifts you into Cat Form if you're not in it, then Dashes (one press when the game allows, otherwise two). Never breaks Prowl.", -- luacheck: no max line length
		body = function()
			local cat = FormIndex("cat")
			if not cat then
				return nil
			end
			-- Dash is off the global cooldown, so it can follow the shift in the same press.
			return ("#showtooltip %s\n/cast [noform:%d] !%s\n/cast [form:%d] %s"):format(S("dash"), cat, S("catForm"), cat, S("dash"))
		end },
	{ key = "pounce", name = "FD Pounce Opener", needs = { "catForm", "prowl", "pounce", "rake" }, default = false,
		desc = "The stun opener: into Cat Form, then Prowl, then Pounce from stealth, then Rake. One key, pressed until the bleeds are up.",
		body = function()
			local cat = FormIndex("cat")
			if not cat then
				return nil
			end
			return ("#showtooltip\n/cast [noform:%d] !%s; [stealth] %s; [nocombat] %s; %s"):format(
				cat, S("catForm"), S("pounce"), S("prowl"), S("rake"))
		end },
	{ key = "moonkin", name = "FD Moonkin Form", needs = { "moonkinForm" }, default = false,
		desc = "Into Moonkin Form from caster or any other form, in one press. Never takes you out of Moonkin Form.",
		body = function()
			return ("#showtooltip %s\n/cast !%s"):format(S("moonkinForm"), S("moonkinForm"))
		end },
	{ key = "hurricane", name = "FD Hurricane", needs = { "hurricane" }, default = false,
		desc = "Hurricane straight at your cursor, with no targeting circle. Drops your form first (not Moonkin Form).",
		body = function()
			return ("#showtooltip %s\n" .. Drop("balance") .. "/cast [@cursor] %s"):format(S("hurricane"), S("hurricane"))
		end },
	{ key = "wildGrowth", name = "FD Wild Growth", needs = { "wildGrowth" }, default = false,
		desc = "Wild Growth on your mouseover, your friendly target, or yourself, healing them and their party. Drops your form first (not Tree of Life).",
		body = function()
			return Helpful(S("wildGrowth"), "heal")
		end },
	{ key = "spiritInnervate", name = "FD Spirit Swap", needs = { "innervate" }, default = false,
		desc = "Innervate on yourself while holding the highest-Spirit weapon in your bags (Innervate boosts Spirit-based regen). Picks the weapon itself; hold Alt and press again to put your usual weapon back.", -- luacheck: no max line length
		ready = function()
			return SpiritWeapon() ~= nil, "a weapon with more Spirit in your bags"
		end,
		body = function()
			local weapon = SpiritWeapon()
			if not weapon then
				return nil
			end
			return ("#showtooltip %s\n" .. Drop("buff") .. SwapLines(weapon) .. "/cast [nomod:alt,@player] %s"):format(
				S("innervate"), S("innervate"))
		end },
	{ key = "bearPotion", name = "FD Survival", renamedFrom = { "FD Bear Potion" }, default = false,
		needs = { { "direBearForm", "bearForm" } },
		desc = "Emergency button while tanking: your best healing potion, and Bear Form if you're not in it, then Frenzied Regeneration once you know it. Potions work in any form on Forever, so you never leave Bear Form. Picks the potion from your bags.", -- luacheck: no max line length
		ready = function()
			return BestCarried(POTIONS) ~= nil, "a healing potion in your bags"
		end,
		body = function()
			local bear, potion = Forms("bear"), BestCarried(POTIONS)
			if not (bear and potion) then
				return nil
			end
			-- The potion is off the global cooldown, so it goes first on every press.
			local after = ns.IsCastable("frenziedRegeneration") and ("; " .. S("frenziedRegeneration")) or ""
			return ("#showtooltip item:%d\n/use item:%d\n/cast [noform:%s] !%s%s"):format(potion, potion, bear, S(ns.BearFormKey()), after)
		end },
	{ key = "stonePotion", name = "FD Healthstone", renamedFrom = { "FD Stone Potion" }, needs = {}, default = false,
		desc = "Your best Healthstone, then your best healing potion on the next press (back to the Healthstone when combat ends). Works in any form. Picks both from your bags.", -- luacheck: no max line length
		ready = function()
			return (BestCarried(HEALTHSTONES) or BestCarried(POTIONS)) ~= nil, "a Healthstone or healing potion in your bags"
		end,
		body = function()
			local stone, potion = BestCarried(HEALTHSTONES), BestCarried(POTIONS)
			if stone and potion then
				return ("#showtooltip\n/castsequence reset=combat item:%d, item:%d"):format(stone, potion)
			end
			local item = stone or potion
			return item and ("#showtooltip item:%d\n/use item:%d"):format(item, item) or nil
		end },
	{ key = "healWrath", name = "FD Heal or Wrath", needs = { "healingTouch", "wrath" }, default = false,
		desc = "One button for levelling: Healing Touch on a friendly mouseover or target, Wrath on an enemy target, Healing Touch on yourself with no target. Drops your form first.", -- luacheck: no max line length
		body = function()
			local heal, wrath = S("healingTouch"), S("wrath")
			return ("#showtooltip\n" .. Drop("none") .. "/cast [@mouseover,help,nodead][help,nodead] %s; [harm,nodead] %s; [@player] %s"):format(
				heal, wrath, heal)
		end },
	{ key = "moonfire", name = "FD Moonfire", needs = { "moonfire" }, default = false,
		desc = "Moonfire on the enemy under your mouse, or your target, so you can dot several mobs without retargeting. Drops your form first (not Moonkin Form).", -- luacheck: no max line length
		body = function()
			return ("#showtooltip %s\n" .. Drop("balance") .. "/cast [@mouseover,harm,nodead][] %s"):format(S("moonfire"), S("moonfire"))
		end },
	{ key = "cleanse", name = "FD Cleanse", needs = { { "abolishPoison", "curePoison", "removeCurse" } }, default = false,
		desc = "Cures poison on your mouseover, your friendly target, or yourself (Abolish Poison once you know it); hold Shift for Remove Curse. Drops your form first (not Moonkin Form or Tree of Life).", -- luacheck: no max line length
		body = function()
			local poison = (ns.IsCastable("abolishPoison") and S("abolishPoison")) or (ns.IsCastable("curePoison") and S("curePoison"))
			local curse = ns.IsCastable("removeCurse") and S("removeCurse")
			local who = "[@mouseover,help,nodead][help,nodead][@player]"
			if poison and curse then
				return ("#showtooltip\n" .. Drop("buff") .. "/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] %s; %s %s"):format( -- luacheck: no max line length
					curse, who, poison)
			end
			local spell = poison or curse
			return ("#showtooltip %s\n" .. Drop("buff") .. "/cast %s %s"):format(spell, who, spell)
		end },
	{ key = "bash", name = "FD Bash", needs = { { "direBearForm", "bearForm" }, "bash" }, default = false,
		desc = "Bash the enemy under your mouse, or your target (stuns and interrupts); hold Shift to Bash your focus. Out of Bear Form the first press shifts you in.", -- luacheck: no max line length
		body = function()
			local bear = Forms("bear")
			if not bear then
				return nil
			end
			-- Bash shares the global cooldown with the shift, so it's the next press.
			return ("#showtooltip %s\n/cast [noform:%s] !%s; [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] %s"):format(
				S("bash"), bear, S(ns.BearFormKey()), S("bash"))
		end },
	{ key = "travel", name = "FD Travel", needs = { { "travelForm", "aquaticForm", "catForm" } }, default = false,
		desc = "One button for getting about: Aquatic Form in water, Travel Form outdoors, Cat Form indoors. Press again in Travel or Aquatic Form to leave it; it never takes you out of Cat Form (or Prowl) indoors.", -- luacheck: no max line length
		body = function()
			local parts = {}
			if ns.IsCastable("aquaticForm") then
				parts[#parts + 1] = "[swimming] " .. S("aquaticForm")
			end
			if ns.IsCastable("travelForm") then
				parts[#parts + 1] = "[outdoors] " .. S("travelForm")
			end
			if ns.IsCastable("catForm") then
				parts[#parts + 1] = "!" .. S("catForm")
			end
			if #parts < 2 then
				return nil -- one form isn't a travel button; FD Cat Form already covers Cat alone
			end
			return "#showtooltip\n/cast " .. table.concat(parts, "; ")
		end },
	{ key = "bearWeapon", name = "FD Bear Weapon", needs = { { "direBearForm", "bearForm" } }, default = false,
		desc = "Equips the weapon in your bags with the most Bear attack power (more than the one you're holding) and shifts into Bear Form. Picks the weapon itself; hold Alt and press again to put your usual weapon back.", -- luacheck: no max line length
		ready = function()
			return M.BearWeapon() ~= nil, "a weapon with more Bear attack power in your bags"
		end,
		body = function()
			local bear, weapon = Forms("bear"), M.BearWeapon()
			if not (bear and weapon) then
				return nil
			end
			return ("#showtooltip %s\n" .. SwapLines(weapon) .. "/cast [nomod:alt,noform:%s] !%s"):format(
				S(ns.BearFormKey()), bear, S(ns.BearFormKey()))
		end },
	{ key = "primalBite", name = "FD Primal Bite", needs = { { "direBearForm", "bearForm" }, "maul", "primalBite" }, default = false,
		desc = "Primal Bite, Forever's high-threat Bear attack, with Maul queued on your next swing in the same press and auto-attack on. Out of Bear Form it shifts you in first.", -- luacheck: no max line length
		body = function()
			return M.MaulWeave("primalBite")
		end },
	{ key = "swipe", name = "FD Swipe", needs = { { "direBearForm", "bearForm" }, "maul", "swipe" }, default = false,
		desc = "Swipe for several mobs, with Maul queued on your next swing in the same press and auto-attack on. Out of Bear Form it shifts you in first.", -- luacheck: no max line length
		body = function()
			return M.MaulWeave("swipe")
		end },
	{ key = "berserk", name = "FD Berserk", needs = { "berserk" }, default = false,
		desc = "Burst: Berserk, plus Tiger's Fury in Cat Form, in one press (neither uses the global cooldown). Out of Cat and Bear Form the first press shifts you into Cat Form.", -- luacheck: no max line length
		body = function()
			local cat, feral = FormIndex("cat"), Forms("cat", "bear")
			if not (cat and feral) then
				return nil
			end
			local fury = ns.IsCastable("tigersFury") and ("\n/cast [form:%d] %s"):format(cat, S("tigersFury")) or ""
			-- Berserk first: if Tiger's Fury is still cooling down, its error doesn't cost you Berserk.
			return ("#showtooltip %s\n/cast [noform:%s] !%s\n/cast [form:%s] %s%s"):format(
				S("berserk"), feral, S("catForm"), feral, S("berserk"), fury)
		end },
	{ key = "insectSwarm", name = "FD Insect Swarm", needs = { "insectSwarm" }, default = false,
		desc = "Insect Swarm on the enemy under your mouse, or your target, to keep it on several mobs without retargeting. Drops your form first (not Moonkin Form).", -- luacheck: no max line length
		body = function()
			return ("#showtooltip %s\n" .. Drop("balance") .. "/cast [@mouseover,harm,nodead][] %s"):format(S("insectSwarm"), S("insectSwarm"))
		end },
	{ key = "sootheAnimal", name = "FD Soothe Animal", needs = { "sootheAnimal" }, default = false,
		desc = "Soothe Animal on the beast under your mouse, or your target: its aggro radius shrinks by 10 yards (the aggro radius markers count it), so you can slip past. Drops your form first (not Moonkin Form).", -- luacheck: no max line length
		body = function()
			return ("#showtooltip %s\n" .. Drop("balance") .. "/cast [@mouseover,harm,nodead][] %s"):format(S("sootheAnimal"), S("sootheAnimal"))
		end },
	{ key = "trinkets", name = "FD Trinkets", needs = {}, default = false,
		desc = "Uses both trinkets at once.",
		body = function()
			return "#showtooltip 13\n/use 13\n/use 14"
		end },
	{ key = "nextTarget", name = "FD Next Target", needs = {}, default = false,
		desc = "Drops a dead or friendly target, picks the nearest enemy if you have none, and starts attacking. Never breaks Prowl.",
		body = function()
			return "#showtooltip\n/cleartarget [dead][help]\n/targetenemy [noexists]\n/startattack [harm,nodead,nostealth]"
		end },
}

local BY_KEY = {}
for _, def in ipairs(M.LIST) do
	BY_KEY[def.key] = def
end

-- How the Macros settings page groups them.
M.GROUPS = {
	{ label = "Healing", keys = { "rejuv", "regrowth", "healingTouch", "swiftHeal", "wildGrowth", "cleanse", "rebirth" } },
	{ label = "Buffs and mana", keys = { "mark", "thorns", "innervate", "spiritInnervate", "barkskin" } },
	{ label = "Forms and travel", keys = { "shiftCat", "shiftBear", "moonkin", "travel", "powershift", "reshift" } },
	{ label = "Cat Form", keys = { "claw", "prowl", "opener", "pounce", "dash", "berserk" } },
	{ label = "Bear Form", keys = { "maul", "lacerate", "primalBite", "swipe", "growl", "bash", "feralCharge", "bearRejuv",
		"bearPotion", "bearWeapon" } },
	{ label = "Balance and crowd control", keys = { "faerie", "moonfire", "insectSwarm", "hurricane", "healWrath", "roots",
		"hibernate", "sootheAnimal" } },
	{ label = "Any form", keys = { "stonePotion", "trinkets", "nextTarget" } },
}
M.BY_KEY = BY_KEY

M.ICON, M.MAX_CHARACTER_MACROS, M.SpellName = ICON, MAX_CHARACTER_MACROS, S
