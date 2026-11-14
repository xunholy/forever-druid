-- The FD macros: what gets written, renames, the slot limit, FD Reshift.
-- Run through tests/run.lua, which provides check, section, noErrors, fresh, login and labels.

---------------------------------------------------------------------------
do
	section("macros: created for known spells, kept up to date, edits left alone, never in combat")
	local W, ns = fresh()
	login(W)
	W.Advance(5)
	local mac = ns.macros
	check(#W.macros.character == 0, "off by default: no macros made at login")

	W.Slash("macros on")
	local names = {}
	for _, m in ipairs(W.macros.character) do
		names[#names + 1] = m.name
	end
	table.sort(names)
	check(table.concat(names, ",") == "FD Barkskin,FD Bear Form,FD Cat Form,FD Innervate,FD Mark,FD Powershift,FD Prowl,FD Rebirth,FD Reshift,FD Thorns",
		"only macros whose spells are known: " .. table.concat(names, ","))
	check(#W.macros.account == 0, "nothing in the account-wide slots")
	local mark = W.CharacterMacro("FD Mark")
	check(mark.body:find("/cast [@mouseover,help,nodead][help,nodead][@player] Mark of the Wild", 1, true), "Mark macro body uses the spell name")
	check(W.CharacterMacro("FD Cat Form").body:find("/cast !Cat Form", 1, true), "FD Cat Form uses !Cat Form")
	check(W.CharacterMacro("FD Ravage Opener") == nil, "the Ravage opener waits for Ravage")
	-- No macro may rely on a form change taking effect within the same key press.
	for _, m in ipairs(W.macros.character) do
		local body = m.body
		check(#body <= 255, m.name .. " fits the macro limit")
		if body:find("/cancelform", 1, true) then
			local cancelAt = body:find("/cancelform", 1, true)
			local stopAt = body:find("/stopmacro", 1, true)
			check(stopAt and stopAt > cancelAt, m.name .. ": stops after /cancelform if you're still shifted, instead of casting blind")
			check(body:find("nostealth", 1, true) ~= nil, m.name .. ": never drops your form while prowling")
		end
	end
	local cat = W.CharacterMacro("FD Cat Form").body
	check(not cat:find("/cancelform", 1, true) and cat:find("/cast !Cat Form", 1, true),
		"FD Cat Form only shifts in: it never takes you out of Cat Form")
	local prowl = W.CharacterMacro("FD Prowl").body
	check(prowl:find("/cast [noform:1] !Cat Form; Prowl", 1, true),
		"FD Prowl: Cat Form first, then Prowl as a toggle, using your stance-bar number for Cat (" .. prowl:gsub("\n", " | ") .. ")")
	local power = W.CharacterMacro("FD Powershift").body
	check(power:find("/cancelform [form:1,nostealth]", 1, true) and power:find("/stopmacro [form:1]", 1, true),
		"FD Powershift leaves and re-enters Cat Form, safely in one or two presses")
	check(mac.Status("mark") == "ready" and mac.Status("rejuv") == "needs", "status: ready / needs a spell")

	-- Learning a spell adds its macro.
	table.insert(W.state.spellbook, { 774, "Rejuvenation" })
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	local rejuv = W.CharacterMacro("FD Rejuvenation")
	check(rejuv and rejuv.body:find("/cancelform [form:1/2/3,nostealth]\n/stopmacro [form:1/2/3]\n/cast", 1, true),
		"learning Rejuvenation creates FD Rejuv (drops your form, then heals)")

	-- An empty spellbook for a moment (login) never deletes anything.
	local saved = W.state.spellbook
	W.state.spellbook = {}
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	check(W.CharacterMacro("FD Mark") ~= nil and W.CharacterMacro("FD Rejuvenation") ~= nil, "a momentarily empty spellbook deletes nothing")
	W.state.spellbook = saved
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)

	-- Your edits are yours.
	W.CharacterMacro("FD Mark").body = "/cast Mark of the Wild\n/say buffed!"
	mac.Sync()
	check(W.CharacterMacro("FD Mark").body:find("/say buffed!", 1, true), "an edited macro isn't overwritten")
	check(mac.Status("mark") == "edited", "status: edited")
	mac.SetWanted("mark", false)
	check(W.CharacterMacro("FD Mark") ~= nil, "unticking an edited macro doesn't delete it")
	mac.SetWanted("mark", true)

	mac.SetWanted("thorns", false)
	check(W.CharacterMacro("FD Thorns") == nil, "unticking deletes ForeverDruid's own macro")
	mac.SetWanted("thorns", true)
	check(W.CharacterMacro("FD Thorns") ~= nil, "ticking brings it back")

	check(mac.Restore() == 1 and not W.CharacterMacro("FD Mark").body:find("/say", 1, true), "restore puts ForeverDruid's text back")
	check(mac.Status("mark") == "ready", "and it's managed again")

	-- Combat: no macro changes, applied when the fight ends.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	mac.SetWanted("thorns", false)
	W.Advance(2)
	check(W.CharacterMacro("FD Thorns") ~= nil and #W.blocked == 0, "no macro changes during combat")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(2)
	check(W.CharacterMacro("FD Thorns") == nil, "applied as the fight ends")
	mac.SetWanted("thorns", true)

	mac.PickUp("mark")
	check(W.pickedMacro == "FD Mark", "pick up puts it on the cursor")

	-- A macro of yours that happens to share a name is never touched.
	W.macros.character[#W.macros.character + 1] = { name = "FD Regrowth", icon = 1, body = "/cast Regrowth\n/y heals" }
	table.insert(W.state.spellbook, { 8936, "Regrowth" })
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	check(W.CharacterMacro("FD Regrowth").body:find("/y heals", 1, true), "a same-named macro of yours is left alone")

	W.Slash("macros")
	W.Slash("macros off")
	local left = {}
	for _, m in ipairs(W.macros.character) do
		left[#left + 1] = m.name
	end
	check(table.concat(left, ",") == "FD Regrowth", "turning management off removes only ForeverDruid's macros (" .. table.concat(left, ",") .. ")")
	check(W.ShowOptionsPanel(), "settings with the Macros page show")
	noErrors(W, "no errors or blocked actions")

	-- Slots full: says so, no error.
	local W2, ns2 = fresh()
	for i = 1, 30 do
		W2.macros.character[i] = { name = ("Mine %02d"):format(i), icon = 1, body = "" }
	end
	login(W2)
	ns2.db.macros.manage = true
	local _, result = ns2.macros.Sync()
	check(result.full and #W2.macros.character == 30, "no free character slots: reported, nothing broken")
	noErrors(W2, "no errors")

	-- Profiles are shared: a warlock on a profile with macros on gets none.
	local W3 = fresh(function(W)
		W.state.class = "WARLOCK"
		ForeverDruidDB = { profiles = { Default = { macros = { manage = true, enabled = {} } } }, chars = {} }
	end)
	login(W3)
	W3.Advance(5)
	check(#W3.macros.character == 0, "no druid macros on other classes")
	noErrors(W3, "no errors")
end

---------------------------------------------------------------------------
do
	section("second review fixes: macros, imports, Dire Bear, restock, rank safety")
	local W, ns = fresh(function(W)
		W.state.level = 40
		for i = #W.state.spellbook, 1, -1 do
			if W.state.spellbook[i][2] == "Bear Form" then
				W.state.spellbook[i] = { 9634, "Dire Bear Form" }
			end
		end
		W.state.extraNames[5487] = "Bear Form"
	end)
	login(W)
	W.Advance(5)
	check(not labels(ns.modules.reminders.active)["Bear Form"], "level 40 with Dire Bear Form: no Bear Form quest reminder")
	ns.macros.SetManaged(true)
	local bear = W.CharacterMacro("FD Bear Form")
	check(bear and bear.body:find("/cast !Dire Bear Form", 1, true), "bear powershift uses Dire Bear Form once you have it")

	-- Restore never touches a macro ForeverDruid didn't write.
	W.macros.character[#W.macros.character + 1] = { name = "FD Rejuv", icon = 1, body = "/cast Rejuvenation\n/s mine" }
	table.sort(W.macros.character, function(a, b) return a.name < b.name end)
	table.insert(W.state.spellbook, { 774, "Rejuvenation" })
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	ns.macros.Restore()
	check(W.CharacterMacro("FD Rejuv").body:find("/s mine", 1, true), "restore leaves your own same-named macro alone")
	W.Slash("macros restore")
	check(#W.popups == 1, "/fd macros restore asks first")
	W.popups = {}

	-- Imports keep your own choices for gold spending, macros and action bars.
	ns.db.restock.enabled = false
	local hostile = { restock = { enabled = true, seeds = 20 }, macros = { manage = false, enabled = { mark = false } },
		ranks = { auto = false, keep = { ["Healing Touch"] = true } } }
	local clean = ns.SanitizeProfile(hostile)
	check(clean.restock.enabled == false and clean.restock.seeds == 20, "import can't switch on reagent buying (amounts still come over)")
	check(clean.macros.manage == true and clean.macros.enabled.mark == nil, "import keeps your macro choices")
	check(clean.ranks.auto == true and clean.ranks.keep["healing touch"], "import keeps your rank setting; kept spells lower-cased")

	-- Restock buys the exact seed or nothing, in capped whole stacks.
	ns.db.restock.enabled = true
	W.state.items[17034] = 5
	W.merchant = { { item = 17038, name = "Ironwood Seed", price = 100 } }
	W.bought = {}
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	check(#W.bought == 0, "never substitutes a different seed for your Rebirth rank")
	W.state.items[17034] = 0
	ns.db.restock.seeds = 5
	W.merchant = { { item = 17034, name = "Maple Seed", price = 100, maxStack = 2 } }
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	local total, biggest = 0, 0
	for _, b in ipairs(W.bought) do
		total, biggest = total + b.count, math.max(biggest, b.count)
	end
	check(total == 5 and biggest <= 2, "buys in chunks no bigger than the vendor's stack limit (" .. total .. " in " .. #W.bought .. ")")
	W.Fire("PLAYER_LEVEL_UP", 42)
	W.tradeskillTrainer = true
	W.Fire("TRAINER_SHOW")
	W.Advance(1)
	check(labels(ns.modules.reminders.active)["Trainer"], "a profession trainer doesn't clear the trainer reminder")
	W.tradeskillTrainer = false

	-- Rank swaps: a pickup that silently fails never clears the button.
	table.insert(W.state.spellbook, { 1430, "Rejuvenation" })
	for _, entry in ipairs(W.state.spellbook) do
		if entry[1] == 774 then
			entry.low = true
		end
	end
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	W.actions[7] = { kind = "spell", id = 774 }
	W.pickupFails = true
	ns.ranks.Upgrade(true)
	check(W.actions[7] and W.actions[7].id == 774, "failed pickup: the button keeps its spell")
	W.pickupFails = false
	ns.ranks.Upgrade(true)
	check(W.actions[7].id == 1430, "then upgrades normally")

	-- Never downgrade: a stale known rank below the button's is ignored.
	W.actions[8] = { kind = "spell", id = 1430 }
	W.state.ranks[2090] = { "Rejuvenation", 4 }
	W.state.extraNames[2090] = "Rejuvenation"
	W.actions[9] = { kind = "spell", id = 2090 }
	ns.ranks.Upgrade(true)
	check(W.actions[9].id == 2090, "a button above your known rank is never moved down")

	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.Slash("ranks now")
	check(W.printed[#W.printed] and W.printed[#W.printed]:find("out of combat", 1, true), "/fd ranks now in combat says it will wait")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	noErrors(W, "no errors or blocked actions")
end

---------------------------------------------------------------------------
do
	section("macros: the wowf.io and forg.gg sets, built to our rules")
	local W, ns = fresh()
	for _, spell in ipairs({ { 774, "Rejuvenation" }, { 18562, "Swiftmend" }, { 1237948, "Revive" }, { 6795, "Growl" },
		{ 6807, "Maul" }, { 1328616, "Lacerate" }, { 1238122, "Feral Charge" }, { 9005, "Pounce" }, { 1822, "Rake" },
		{ 6800, "Shred" }, { 6785, "Ravage" }, { 1082, "Claw" }, { 24858, "Moonkin Form" }, { 16914, "Hurricane" },
		{ 408120, "Wild Growth" }, { 21849, "Gift of the Wild" }, { 5185, "Healing Touch" }, { 5179, "Wrath" },
		{ 8921, "Moonfire" }, { 2893, "Abolish Poison" }, { 2782, "Remove Curse" }, { 6798, "Bash" },
		{ 22842, "Frenzied Regeneration" }, { 1066, "Aquatic Form" }, { 339, "Entangling Roots" }, { 2637, "Hibernate" },
		{ 407995, "Primal Bite" }, { 769, "Swipe" }, { 417141, "Berserk" }, { 5570, "Insect Swarm" }, { 2908, "Soothe Animal" } }) do
		table.insert(W.state.spellbook, spell)
	end
	W.state.forms = { 768, 5487, 783, 24858 } -- cat 1, bear 2, travel 3, moonkin 4
	W.RebuildNames()
	login(W)
	W.Advance(5)
	local mac = ns.macros
	W.Slash("macros on")
	W.Advance(2)
	local function Body(name)
		local m = W.CharacterMacro(name)
		return m and m.body or ""
	end
	-- The house rules, for every FD macro.
	local function HouseRules()
		for _, m in ipairs(W.macros.character) do
			local body = m.body
			check(#body <= 255, m.name .. " fits the macro limit")
			local cancelAt = body:find("/cancelform", 1, true)
			if cancelAt then
				local stopAt = body:find("/stopmacro", cancelAt, true)
				check(stopAt ~= nil, m.name .. ": stops after /cancelform if you're still shifted")
				local guard = body:match("/cancelform (%b[])")
				check(guard and (guard:find("nostealth", 1, true) or guard:match("^%[form:%d%]$")),
					m.name .. ": never drops Prowl (" .. tostring(guard) .. ")")
			end
			check(not body:find("nil", 1, true), m.name .. " has no missing names")
		end
	end
	local NEW = { "FD Growl", "FD Maul Lacerate", "FD Feral Charge", "FD Dash", "FD Pounce Opener", "FD Moonkin Form",
		"FD Hurricane", "FD Wild Growth", "FD Spirit Swap", "FD Survival", "FD Healthstone", "FD Trinkets",
		"FD Next Target", "FD Heal or Wrath", "FD Moonfire", "FD Cleanse", "FD Bash", "FD Travel", "FD Bear Weapon",
		"FD Primal Bite", "FD Swipe", "FD Berserk", "FD Insect Swarm", "FD Soothe Animal" }
	local none = true
	for _, name in ipairs(NEW) do
		none = none and W.CharacterMacro(name) == nil
	end
	check(none, "the new macros start off, so they don't fill your macro slots")
	check(mac.IsTicked("rejuv") and not mac.IsTicked("growl"), "existing macros stay on, new ones are off until ticked")
	for _, def in ipairs(mac.LIST) do
		check(#def.name <= 16 and def.name:sub(1, 3) == "FD ", def.name .. ": FD prefix, fits the 16-character name limit")
	end

	-- Upgrades to the macros you already have.
	check(Body("FD Rejuvenation"):find("[mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] Swiftmend; [@mouseover,help,nodead][help,nodead][@player] Rejuvenation", 1, true), -- luacheck: no max line length
		"FD Rejuvenation: Shift for Swiftmend once you know it")
	check(Body("FD Mark"):find("[mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] Gift of the Wild; [@mouseover,help,nodead][help,nodead][@player] Mark of the Wild", 1, true), -- luacheck: no max line length
		"FD Mark: Shift for Gift of the Wild")
	check(Body("FD Rebirth"):find("[combat,@mouseover,help,dead][combat,help,dead] Rebirth; [@mouseover,help,dead][help,dead] Revive", 1, true),
		"FD Rebirth: Rebirth in combat, Revive out of it")
	check(Body("FD Prowl"):find("/dismount [mounted]\n/cast [noform:1] !Cat Form; Prowl", 1, true), "FD Prowl: off the mount first")
	check(Body("FD Ravage Opener"):find("/cast [noform:1] !Cat Form; [stealth] Ravage; [nocombat] Prowl; Shred", 1, true),
		"FD Ravage Opener: Ravage from stealth, Prowl out of combat, Shred once the fight is on")
	check(Body("FD Roots"):find("/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] Entangling Roots", 1, true)
		and Body("FD Hibernate"):find("[mod:shift,@focus,harm,nodead]", 1, true), "FD Roots and FD Hibernate: Shift for your focus")

	-- Forms that can still cast the spell aren't dropped (Forever's shapeshift masks).
	check(Body("FD Mark"):find("/cancelform [form:1/2/3,nostealth]\n/stopmacro [form:1/2/3]", 1, true),
		"buffs drop Cat, Bear and Travel Form but not Moonkin Form")
	check(Body("FD Rejuvenation"):find("/cancelform [form:1/2/3/4,nostealth]", 1, true), "heals drop Moonkin Form too")
	check(Body("FD Hibernate"):find("/cancelform [form:1/2/3,nostealth]", 1, true), "Balance spells keep Moonkin Form")
	check(Body("FD Roots"):find("/cancelform [form:1/2/3/4,nostealth]", 1, true), "Roots needs caster form (Moonkin can't root on Forever)")
	check(Body("FD Barkskin") == "#showtooltip Barkskin\n/cast Barkskin", "FD Barkskin works in any form: no form drop")

	-- Item macros wait for the item and say so.
	mac.SetWanted("bearPotion", true)
	local status, text = mac.Status("bearPotion"), ns.MacroStatusText("bearPotion")
	check(status == "needs" and text:find("healing potion", 1, true) and W.CharacterMacro("FD Survival") == nil,
		"no potion in your bags: 'needs a healing potion', nothing created (" .. text .. ")")

	-- Bags: two potions (Forever's Discolored one heals more), a Healthstone, a Spirit staff, a bear mace.
	W.state.items[13446], W.state.items[241650], W.state.items[5509] = 3, 1, 1
	W.bags[0] = { "item:staff", "item:bearmace" }
	W.itemSlots["item:staff"], W.itemIDs["item:staff"] = "INVTYPE_2HWEAPON", 4321
	W.itemStats["item:staff"] = { ITEM_MOD_SPIRIT_SHORT = 20 }
	W.itemSlots["item:bearmace"], W.itemIDs["item:bearmace"] = "INVTYPE_WEAPON", 5555
	W.itemStats["item:bearmace"] = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 60 }
	W.equipped[16], W.equipped[17] = "item:mace", "item:orb"
	W.itemIDs["item:mace"], W.itemIDs["item:orb"] = 1111, 2222
	W.itemStats["item:mace"] = { ITEM_MOD_SPIRIT_SHORT = 4, ITEM_MOD_STRENGTH_SHORT = 2 }
	for _, def in ipairs(mac.LIST) do
		if def.default == false then
			mac.SetWanted(def.key, true)
		end
	end
	W.Advance(2)
	check(#W.macros.character == 30 and mac.lastSync.full, "ticking everything fills the 30 slots and says so, nothing breaks")
	local slots = mac.Slots()
	check(slots.used == 30 and slots.free == 0 and slots.ours == 30 and slots.waiting > 0,
		"slot count: 30 of 30 used, with ticked macros left waiting (" .. slots.waiting .. ")")
	local waitingKey
	for _, def in ipairs(mac.LIST) do
		if mac.Status(def.key) == "full" then
			waitingKey = def.key
		end
	end
	check(waitingKey ~= nil and ns.MacroStatusText(waitingKey):find("no free macro slot", 1, true),
		"a ticked macro with nowhere to go says 'no free macro slot'")
	check(ns.MacroSlotsText():find("30 of 30 used", 1, true) and ns.MacroSlotsText():find("have no slot to go in", 1, true),
		"the Macros page says the slots are full and how many are waiting")
	local grouped, twice = {}, {}
	for _, group in ipairs(mac.GROUPS) do
		for _, key in ipairs(group.keys) do
			if grouped[key] or not mac.BY_KEY[key] then
				twice[#twice + 1] = key
			end
			grouped[key] = true
		end
	end
	local ungrouped = {}
	for _, def in ipairs(mac.LIST) do
		if not grouped[def.key] then
			ungrouped[#ungrouped + 1] = def.key
		end
	end
	check(#ungrouped == 0 and #twice == 0, "every macro is in exactly one group on the Macros page (missing: "
		.. table.concat(ungrouped, ",") .. "; twice or unknown: " .. table.concat(twice, ",") .. ")")
	check(W.ShowOptionsPanel(), "the grouped Macros page builds")
	HouseRules() -- the original set, with every spell known
	-- Make room: untick the original set (they're checked above).
	for _, def in ipairs(mac.LIST) do
		if def.default ~= false then
			mac.SetWanted(def.key, false)
		end
	end
	W.Advance(2)
	local missing = {}
	for _, name in ipairs(NEW) do
		if not W.CharacterMacro(name) then
			missing[#missing + 1] = name
		end
	end
	check(#missing == 0, "ticked: every new macro is made (missing: " .. table.concat(missing, ", ") .. ")")
	check(Body("FD Growl"):find("/cast [noform:2] !Bear Form\n/cast [form:2,@mouseover,harm,nodead][form:2] Growl", 1, true),
		"FD Growl: mouseover Growl in Bear Form, shifting in first")
	check(Body("FD Maul Lacerate"):find("/stopmacro [noform:2]\n/startattack\n/cast Maul\n/cast Lacerate", 1, true),
		"FD Maul Lacerate: Maul and Lacerate in one press, only in Bear Form")
	check(Body("FD Feral Charge"):find("/cast [noform:1/2] !Bear Form\n/cast [form:1/2,@mouseover,harm,nodead][form:1/2] Feral Charge", 1, true),
		"FD Feral Charge: from Cat (leap) or Bear (charge), Bear Form from anything else")
	check(Body("FD Dash"):find("/cast [noform:1] !Cat Form\n/cast [form:1] Dash", 1, true), "FD Dash: Cat Form if needed, then Dash")
	check(Body("FD Pounce Opener"):find("/cast [noform:1] !Cat Form; [stealth] Pounce; [nocombat] Prowl; Rake", 1, true),
		"FD Pounce Opener: Cat, Prowl, Pounce, Rake")
	check(Body("FD Moonkin Form") == "#showtooltip Moonkin Form\n/cast !Moonkin Form", "FD Moonkin Form never toggles you out")
	check(Body("FD Hurricane"):find("/cast [@cursor] Hurricane", 1, true), "FD Hurricane at the cursor")
	check(Body("FD Wild Growth"):find("[@mouseover,help,nodead][help,nodead][@player] Wild Growth", 1, true), "FD Wild Growth on mouseover")
	check(Body("FD Spirit Swap"):find("/equip [mod:alt] item:1111; item:4321\n/equipslot [mod:alt] 17 item:2222\n/cast [nomod:alt,@player] Innervate", 1, true), -- luacheck: no max line length
		"FD Spirit Swap picks the higher-Spirit staff; Alt puts your mace and off-hand back (" .. Body("FD Spirit Swap"):gsub("\n", " | ") .. ")")
	check(Body("FD Survival"):find("/use item:241650\n/cast [noform:2] !Bear Form; Frenzied Regeneration", 1, true)
		and not Body("FD Survival"):find("cancelform", 1, true),
		"FD Survival: the best potion without leaving Bear Form, then Frenzied Regeneration")
	check(Body("FD Healthstone"):find("/castsequence reset=combat item:5509, item:241650", 1, true)
		and not Body("FD Healthstone"):find("cancelform", 1, true), "FD Healthstone: Healthstone, then the best potion, in any form")
	check(Body("FD Next Target"):find("/startattack [harm,nodead,nostealth]", 1, true), "FD Next Target never breaks Prowl")
	check(Body("FD Heal or Wrath"):find("/cast [@mouseover,help,nodead][help,nodead] Healing Touch; [harm,nodead] Wrath; [@player] Healing Touch", 1, true),
		"FD Heal or Wrath: heal friends, Wrath enemies, heal yourself")
	check(Body("FD Moonfire"):find("/cast [@mouseover,harm,nodead][] Moonfire", 1, true), "FD Moonfire on mouseover")
	check(Body("FD Cleanse"):find("[mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] Remove Curse; [@mouseover,help,nodead][help,nodead][@player] Abolish Poison", 1, true), -- luacheck: no max line length
		"FD Cleanse: Abolish Poison, Shift for Remove Curse")
	check(Body("FD Bash"):find("/cast [noform:2] !Bear Form; [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] Bash", 1, true),
		"FD Bash from any form; Shift for your focus (interrupts)")
	check(Body("FD Primal Bite"):find("/cast [noform:2] !Bear Form\n/stopmacro [noform:2]\n/startattack\n/cast Maul\n/cast Primal Bite", 1, true)
		and Body("FD Swipe"):find("/startattack\n/cast Maul\n/cast Swipe", 1, true),
		"FD Primal Bite and FD Swipe weave Maul into the same press, in Bear Form only")
	check(Body("FD Berserk"):find("/cast [noform:1/2] !Cat Form\n/cast [form:1/2] Berserk\n/cast [form:1] Tiger's Fury", 1, true),
		"FD Berserk: Berserk in Cat or Bear Form, plus Tiger's Fury in Cat Form, Berserk first")
	check(Body("FD Insect Swarm"):find("/cancelform [form:1/2/3,nostealth]", 1, true)
		and Body("FD Insect Swarm"):find("/cast [@mouseover,harm,nodead][] Insect Swarm", 1, true),
		"FD Insect Swarm on mouseover, keeping Moonkin Form")
	check(Body("FD Soothe Animal"):find("/cast [@mouseover,harm,nodead][] Soothe Animal", 1, true)
		and Body("FD Soothe Animal"):find("/cancelform [form:1/2/3,nostealth]", 1, true),
		"FD Soothe Animal on mouseover, keeping Moonkin Form")
	check(Body("FD Travel") == "#showtooltip\n/cast [swimming] Aquatic Form; [outdoors] Travel Form; !Cat Form",
		"FD Travel: Aquatic in water, Travel outdoors, Cat indoors (never toggling Cat off)")
	check(Body("FD Bear Weapon"):find("/equip [mod:alt] item:1111; item:5555\n/equipslot [mod:alt] 17 item:2222\n/cast [nomod:alt,noform:2] !Bear Form", 1, true), -- luacheck: no max line length
		"FD Bear Weapon picks the weapon with the most Bear attack power; Alt swaps back")
	-- After the swap nothing in your bags beats what you hold: the macro keeps its swap-back.
	local before = Body("FD Spirit Swap")
	W.equipped[16], W.bags[0] = "item:staff", { "item:mace", "item:bearmace" }
	W.itemSlots["item:mace"] = "INVTYPE_WEAPON"
	W.Fire("PLAYER_EQUIPMENT_CHANGED", 16)
	W.Advance(2)
	check(Body("FD Spirit Swap") == before and mac.Status("spiritInnervate") == "ready",
		"holding the Spirit staff: the macro is left as written, so Alt still swaps back")
	W.equipped[16], W.bags[0] = "item:mace", { "item:staff", "item:bearmace" }
	W.Fire("PLAYER_EQUIPMENT_CHANGED", 16)
	W.Advance(2)

	-- Bags change: the best potion runs out or is too high a level, and the macros follow.
	W.state.items[241650] = 0
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(2)
	check(Body("FD Survival"):find("item:13446", 1, true) and Body("FD Healthstone"):find("item:5509, item:13446", 1, true),
		"used the last one: both switch to the next-best potion")
	W.state.items[241650] = 1
	W.unusable[241650] = true
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(2)
	check(Body("FD Survival"):find("item:13446", 1, true), "a potion too high for your level is skipped")
	W.state.items[5509] = 0
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(2)
	check(Body("FD Healthstone"):find("/use item:13446", 1, true), "no Healthstone: just the potion")

	HouseRules()
	check(#W.macros.character <= 30, "within the 30 character macro slots")
	noErrors(W, "no Lua errors or blocked actions")
end

---------------------------------------------------------------------------
do
	section("macros follow your stance bar: Bear 1, Aquatic 2, Cat 3 (a real level-21 layout)")
	local W, ns = fresh(function(W)
		W.state.forms = { 5487, 1066, 768 }
		W.state.extraNames[1066] = "Aquatic Form"
		W.RebuildNames()
		table.insert(W.state.spellbook, { 1066, "Aquatic Form" })
	end)
	login(W)
	W.Advance(5)
	ns.macros.SetManaged(true)
	local prowl = W.CharacterMacro("FD Prowl").body
	check(prowl:find("[noform:3] !Cat Form; Prowl", 1, true), "FD Prowl uses Cat = 3")
	local power = W.CharacterMacro("FD Powershift").body
	check(power:find("[form:3,nostealth]", 1, true) and power:find("/stopmacro [form:3]", 1, true), "FD Powershift uses Cat = 3")
	local faerie = W.CharacterMacro("FD Faerie Fire")
	check(faerie == nil or not faerie.body:find("form:2", 1, true), "Aquatic Form (2) never counts as Cat or Bear")
	-- Learning Travel Form adds a 4th form: macros are rebuilt and Cat stays 3.
	W.state.forms[4] = 783
	W.Fire("UPDATE_SHAPESHIFT_FORMS")
	W.Advance(3)
	check(W.CharacterMacro("FD Prowl").body:find("[noform:3]", 1, true), "still Cat = 3 after learning another form")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	section("upgrading existing FD macros (the game keeps a trailing line break)")
	local old = "#showtooltip Cat Form\n/cancelform [form,nostealth]\n/cast !Cat Form"
	local W, ns = fresh(function(W)
		W.state.forms = { 5487, 1066, 768 }
		W.state.extraNames[1066] = "Aquatic Form"
		W.RebuildNames()
		-- What a character had before the fix: the old FD Shift Cat, saved by the game, and
		-- ForeverDruid's record of having written it.
		W.macros.character[1] = { name = "FD Shift Cat", icon = 134400, body = old .. "\n" }
		W.macros.character[2] = { name = "Power Cat", icon = 134400, body = old .. "\n" }
		ForeverDruidDB = { profiles = { Default = { macros = { manage = true, enabled = {} } } }, chars = {},
			macroBodies = { ["Testdruid - Testrealm"] = { shiftCat = old } } }
	end)
	login(W)
	W.Advance(5)
	local cat = W.CharacterMacro("FD Cat Form")
	check(cat and not cat.body:find("/cancelform", 1, true) and cat.body:find("/cast !Cat Form", 1, true)
		and W.CharacterMacro("FD Shift Cat") == nil,
		"an old FD Shift Cat is renamed FD Cat Form and rewritten to the fixed version")
	check(ns.macros.Status("shiftCat") == "ready", "and counts as ForeverDruid's, not 'edited by you'")
	local catMacros = 0
	for _, m in ipairs(W.macros.character) do
		if m.body:find("!Cat Form", 1, true) and m.name:find("^FD") and not m.name:find("Prowl")
			and not m.name:find("Powershift") then
			catMacros = catMacros + 1
		end
	end
	check(catMacros == 1, "renamed in place, not duplicated (" .. catMacros .. ")")
	noErrors(W, "no errors after the rename")

	-- One you edited under its old name: left alone under that name, and no second copy is made.
	local edited = "#showtooltip Bear Form\n/cast !Bear Form\n/say rawr"
	local W2, ns2 = fresh(function(W2)
		W2.macros.character[1] = { name = "FD Shift Bear", icon = 134400, body = edited }
		ForeverDruidDB = { profiles = { Default = { macros = { manage = true, enabled = {} } } }, chars = {},
			macroBodies = { ["Testdruid - Testrealm"] = { shiftBear = "#showtooltip Bear Form\n/cast !Bear Form" } } }
	end)
	login(W2)
	W2.Advance(5)
	check(W2.CharacterMacro("FD Shift Bear").body == edited and W2.CharacterMacro("FD Bear Form") == nil
		and ns2.macros.Status("shiftBear") == "edited",
		"an FD macro you edited keeps its old name and your text, with no duplicate under the new name")
	check(W.CharacterMacro("Power Cat").body == old .. "\n", "your own macros (Power Cat) are never touched")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	section("FD Reshift (powershift whatever form you're in) and FD Bear Rejuv")
	local W, ns = fresh(function(W)
		W.state.forms = { 5487, 1066, 768 } -- Bear 1, Aquatic 2, Cat 3
		W.state.extraNames[1066] = "Aquatic Form"
		W.RebuildNames()
		table.insert(W.state.spellbook, { 774, "Rejuvenation" })
	end)
	login(W)
	W.Advance(5)
	ns.macros.SetManaged(true)
	W.Advance(2)
	local reshiftMacro = W.CharacterMacro("FD Reshift")
	check(reshiftMacro and reshiftMacro.body:find("/click ForeverDruidReshift", 1, true) and reshiftMacro.icon == 132115,
		"FD Reshift clicks ForeverDruid's reshift button, with the Cat Form icon")
	local button = _G.ForeverDruidReshift
	check(button and button:GetAttribute("type") == "macro" and button:GetAttribute("useOnKeyDown") == false,
		"the button runs a macro and acts on the release a /click sends")

	local function at(form)
		W.state.form = form
		W.UpdateStateDrivers()
		return button:GetAttribute("macrotext") or ""
	end
	local inCat = at(3)
	check(inCat:find("/cancelform [nostealth]", 1, true) and inCat:find("/stopmacro [form]", 1, true) and inCat:find("/cast !Cat Form", 1, true),
		"in Cat Form: leave it and try straight back into Cat (never while prowling)")
	check(at(0) == "/cast !Cat Form", "then in caster form it shifts back into Cat, the form you came from")
	local inBear = at(1)
	check(inBear:find("/cancelform", 1, true) and inBear:find("/cast !Bear Form", 1, true), "in Bear Form: leave it and back into Bear")
	check(at(0) == "/cast !Bear Form", "and back into Bear after a second press")
	check(at(2) == "/cast !Bear Form", "Aquatic or another form: back into your last Cat or Bear form")

	local bearRejuv = W.CharacterMacro("FD Bear Rejuv").body
	check(bearRejuv:find("/cancelform [form:1]", 1, true) and bearRejuv:find("/stopmacro [form:1]", 1, true),
		"FD Bear Rejuv drops Bear Form (Bear = 1), stopping if still shifted")
	check(bearRejuv:find("/castsequence [@mouseover,help,nodead][@player] reset=8 Rejuvenation, Bear Form", 1, true),
		"then Rejuvenation, then back into Bear Form, on one key")
	check(not bearRejuv:find("!Bear", 1, true), "no ! in the sequence (it would stop the sequence moving on)")
	check(#bearRejuv <= 255, "fits the macro limit")

	-- Learning forms later rebuilds the button's form numbers out of combat.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.state.forms[4] = 783
	W.Fire("UPDATE_SHAPESHIFT_FORMS")
	W.Advance(2)
	check(#W.blocked == 0, "no secure changes in combat")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(3)
	check(at(3):find("/cast !Cat Form", 1, true), "still right after learning Travel Form")
	noErrors(W, "no errors or blocked actions")
end
