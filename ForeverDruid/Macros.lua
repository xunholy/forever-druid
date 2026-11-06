-- Druid macros, created and kept up to date by the addon.
--
-- Only macros named "FD ..." are ever touched, and only ones ForeverDruid wrote itself: the body
-- it last wrote is remembered per character, and a macro whose text no longer matches (you edited
-- it) is left alone. Macros go in the character's own slots, so other characters never see them.
-- Spell names come from the client, so the macros work in any language.
--
-- Nothing is deleted because a spell seems unknown (the spellbook can be empty for a moment at
-- login); a macro is only removed when you untick it or turn macro management off.

local _, ns = ...
local L = ns.L

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

local function Helpful(spell)
	return ("#showtooltip %s\n" .. CASTER .. "/cast [@mouseover,help,nodead][help,nodead][@player] %s"):format(spell, spell)
end

local function Harmful(spell)
	return ("#showtooltip %s\n" .. CASTER .. "/cast [@mouseover,harm,nodead][] %s"):format(spell, spell)
end

-- key, macro name (16 chars max), spells it needs, body builder, what it does.
M.LIST = {
	{ key = "rejuv", name = "FD Rejuv", needs = { "rejuvenation" },
		desc = "Rejuvenation on your mouseover, your friendly target, or yourself. In a form it drops the form first (press again if it needs a second press).",
		body = function()
			return Helpful(S("rejuvenation"))
		end },
	{ key = "regrowth", name = "FD Regrowth", needs = { "regrowth" },
		desc = "Regrowth on your mouseover, your friendly target, or yourself, dropping your form first.",
		body = function()
			return Helpful(S("regrowth"))
		end },
	{ key = "healingTouch", name = "FD Heal Touch", needs = { "healingTouch" },
		desc = "Healing Touch on your mouseover, your friendly target, or yourself, dropping your form first.",
		body = function()
			return Helpful(S("healingTouch"))
		end },
	{ key = "mark", name = "FD Mark", needs = { "markOfTheWild" },
		desc = "Mark of the Wild on your mouseover, your friendly target, or yourself, without changing target.",
		body = function()
			return Helpful(S("markOfTheWild"))
		end },
	{ key = "thorns", name = "FD Thorns", needs = { "thorns" },
		desc = "Thorns on your mouseover, your friendly target, or yourself.",
		body = function()
			return Helpful(S("thorns"))
		end },
	{ key = "innervate", name = "FD Innervate", needs = { "innervate" },
		desc = "Innervate on your mouseover, your friendly target, or yourself.",
		body = function()
			return Helpful(S("innervate"))
		end },
	{ key = "rebirth", name = "FD Rebirth", needs = { "rebirth" },
		desc = "Rebirth on the dead party member under your mouse, or your dead target.",
		body = function()
			return ("#showtooltip %s\n" .. CASTER .. "/cast [@mouseover,help,dead][help,dead] %s"):format(S("rebirth"), S("rebirth"))
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
		desc = "Entangling Roots on the enemy under your mouse, or your target, dropping your form first.",
		body = function()
			return Harmful(S("entanglingRoots"))
		end },
	{ key = "hibernate", name = "FD Hibernate", needs = { "hibernate" },
		desc = "Hibernate on the beast under your mouse, or your target, dropping your form first.",
		body = function()
			return Harmful(S("hibernate"))
		end },
	{ key = "shiftCat", name = "FD Shift Cat", needs = { "catForm" },
		desc = "Into Cat Form from caster or Bear Form, in one press. Never takes you out of Cat Form.",
		body = function()
			return ("#showtooltip %s\n/cast !%s"):format(S("catForm"), S("catForm"))
		end },
	{ key = "shiftBear", name = "FD Shift Bear", needs = { { "direBearForm", "bearForm" } },
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
	{ key = "prowl", name = "FD Prowl", needs = { "catForm", "prowl" },
		desc = "Tap: into Cat Form. Tap again: Prowl. Tap while prowling: leave Prowl, staying in Cat Form.",
		body = function()
			local cat = FormIndex("cat")
			if not cat then
				return nil
			end
			return ("#showtooltip %s\n/cast [noform:%d] !%s; %s"):format(S("prowl"), cat, S("catForm"), S("prowl"))
		end },
	{ key = "opener", name = "FD Opener", needs = { "catForm", "prowl", "ravage" },
		desc = "Into Cat Form, then Prowl, then Ravage from stealth: one key for the whole opener.",
		body = function()
			local cat = FormIndex("cat")
			if not cat then
				return nil
			end
			return ("#showtooltip\n/cast [noform:%d] !%s; [nostealth] %s; %s"):format(cat, S("catForm"), S("prowl"), S("ravage"))
		end },
	{ key = "faerie", name = "FD Faerie", needs = { { "faerieFireFeral", "faerieFire" } },
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
		desc = "Barkskin, dropping your form first if you're in one.",
		body = function()
			return ("#showtooltip %s\n" .. CASTER .. "/cast %s"):format(S("barkskin"), S("barkskin"))
		end },
	{ key = "swiftHeal", name = "FD Swift Heal", needs = { "naturesSwiftness", "healingTouch" },
		desc = "Emergency heal: drops your form, Nature's Swiftness, then an instant Healing Touch on your mouseover, friendly target or yourself.",
		body = function()
			return ("#showtooltip %s\n" .. CASTER .. "/cast %s\n/cast [@mouseover,help,nodead][help,nodead][@player] %s"):format(
				S("naturesSwiftness"), S("naturesSwiftness"), S("healingTouch"))
		end },
}

local BY_KEY = {}
for _, def in ipairs(M.LIST) do
	BY_KEY[def.key] = def
end
M.BY_KEY = BY_KEY

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function Config()
	return ns.db.macros
end

-- Bodies ForeverDruid last wrote, per character: global.macroBodies[charKey][key] = body.
local function Written()
	ns.global.macroBodies = ns.global.macroBodies or {}
	local mine = ns.global.macroBodies[ns.charKey]
	if not mine then
		mine = {}
		ns.global.macroBodies[ns.charKey] = mine
	end
	return mine
end

function M.IsWanted(key)
	local cfg = Config()
	return cfg.manage and cfg.enabled[key] ~= false
end

-- Each need is a spell key, or a list of keys where any one will do (Dire Bear Form replaces
-- Bear Form at 40).
function M.HasSpells(def)
	for _, need in ipairs(def.needs) do
		local options = type(need) == "table" and need or { need }
		local any = false
		for _, spell in ipairs(options) do
			any = any or ns.IsCastable(spell)
		end
		if not any then
			return false, options[#options]
		end
	end
	return true
end

-- A body is only ever built once every spell name is known (never "nil" in a macro).
local function Body(def)
	if not M.HasSpells(def) then
		return nil
	end
	local ok, body = pcall(def.body)
	if ok and type(body) == "string" and #body <= 255 then
		return body
	end
	return nil
end
M.Body = Body

local function Existing(def)
	local index = GetMacroIndexByName and GetMacroIndexByName(def.name) or 0
	if not index or index == 0 then
		return nil
	end
	local _, _, body = GetMacroInfo(index)
	return index, body
end

-- "ready", "edited" (you changed it: left alone), "missing" (not created yet),
-- "needs" (a spell isn't learned yet), "off".
function M.Status(key)
	local def = BY_KEY[key]
	local index, body = Existing(def)
	local written = Written()[key]
	if index and written and body ~= written then
		return "edited"
	end
	if not M.IsWanted(key) then
		return "off"
	end
	if index then
		return "ready"
	end
	local has, missing = M.HasSpells(def)
	if not has then
		return "needs", missing
	end
	return "missing"
end

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------

M.lastSync = { created = 0, updated = 0, removed = 0, skipped = 0, full = false }
local pending = false

local function CharacterSlotsFree()
	local _, perCharacter = GetNumMacros()
	return MAX_CHARACTER_MACROS - (tonumber(perCharacter) or 0)
end

-- Brings the FD macros in line with the settings. Out of combat only (the client refuses macro
-- changes in combat); asked for in combat, it runs as the fight ends.
function M.Sync()
	if not (ns.isDruid and CreateMacro and EditMacro and DeleteMacro and GetMacroInfo and GetNumMacros) then
		return false -- profiles are shared across characters; druid macros stay on druids
	end
	if InCombatLockdown() then
		pending = true
		return false
	end
	pending = false
	local written = Written()
	local result = { created = 0, updated = 0, removed = 0, skipped = 0, full = false }
	local function One(def)
		local index, current = Existing(def)
		local ours = index and written[def.key] and current == written[def.key]
		if index and written[def.key] and not ours then
			result.skipped = result.skipped + 1 -- you edited it: hands off
		elseif M.IsWanted(def.key) then
			local body = Body(def)
			if body then
				if not index then
					if CharacterSlotsFree() > 0 then
						local created = CreateMacro(def.name, ICON, body, true)
						if type(created) == "number" and created > 0 then
							written[def.key] = body
							result.created = result.created + 1
						end
					else
						result.full = true
					end
				elseif current == body then
					written[def.key] = body -- adopt an identical macro (e.g. after a reinstall)
				elseif ours then
					EditMacro(index, nil, nil, body)
					written[def.key] = body
					result.updated = result.updated + 1
				else
					result.skipped = result.skipped + 1 -- a macro of yours already has this name
				end
			end
		elseif ours then
			DeleteMacro(index)
			written[def.key] = nil
			result.removed = result.removed + 1
		end
	end
	for _, def in ipairs(M.LIST) do
		-- One bad macro (or a client refusal) never stops the rest.
		local ok, err = pcall(One, def)
		if not ok then
			ns.ReportError(err)
		end
	end
	M.lastSync = result
	ns.Fire("FD_MACROS_CHANGED", result)
	return true, result
end

local function Queue()
	if ns.isDruid and ns.db and ns.db.macros.manage then
		ns.Debounce("macros", 1, M.Sync)
	end
end

function M.SetManaged(on)
	local cfg = Config()
	cfg.manage = on and true or false
	if InCombatLockdown() then
		pending = true
		ns.Print(L["macros will update when the fight ends"])
		return
	end
	local _, result = M.Sync()
	M.Report(result)
end

function M.SetWanted(key, on)
	Config().enabled[key] = on and true or false
	if InCombatLockdown() then
		pending = true
		return
	end
	M.Sync()
end

function M.Report(result)
	if not result then
		return
	end
	ns.Print(("%s: %d %s, %d %s, %d %s"):format(L["macros"], result.created, L["created"], result.updated, L["updated"], result.removed, L["removed"]))
	if result.full then
		ns.Print(L["no free character macro slots: delete one in /macro to make room"])
	end
	if result.skipped > 0 then
		ns.Print(L["left alone because you edited them:"] .. " " .. result.skipped)
	end
end

-- Overwrites FD macros you edited with ForeverDruid's version again (asked for explicitly).
function M.Restore()
	if InCombatLockdown() then
		ns.Print(L["can't change macros during combat"])
		return 0
	end
	local written, restored = Written(), 0
	for _, def in ipairs(M.LIST) do
		local index, current = Existing(def)
		-- Only macros ForeverDruid wrote: a macro of yours that shares a name is never touched.
		local body = index and written[def.key] and M.IsWanted(def.key) and Body(def)
		if body and current ~= body then
			EditMacro(index, nil, nil, body)
			written[def.key] = body
			restored = restored + 1
		end
	end
	return restored
end

-- Puts the macro on your cursor to drop on an action bar.
function M.PickUp(key)
	if InCombatLockdown() then
		ns.Print(L["can't pick up macros during combat"])
		return false
	end
	local index = Existing(BY_KEY[key])
	if not index then
		ns.Print(L["that macro doesn't exist yet"])
		return false
	end
	PickupMacro(index)
	return true
end

ns.Listen("FD_SPELLS_CHANGED", Queue)
-- Learning a form can renumber your stance bar; the form-numbered macros follow it.
ns.On("UPDATE_SHAPESHIFT_FORMS", Queue)
ns.Listen("FD_LOGIN", function()
	if ns.isDruid then
		Queue()
	end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
	if pending then
		ns.Debounce("macros", 0.5, M.Sync)
	end
end)
