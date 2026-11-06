-- Runs ForeverDruid against the WoW Forever stub: login, every form, combat with secret values,
-- energy tick learning, target auras, click-to-cast reminders, profiles, slash commands and the
-- options panel. Exits non-zero on any Lua error, blocked protected action or failed expectation.
--   lua tests/run.lua

package.path = "./tests/?.lua;" .. package.path

local out = print -- the stub replaces the global print to capture addon chat output
local failures = 0
local function check(cond, message)
	if cond then
		out("  ok   " .. message)
	else
		failures = failures + 1
		out("  FAIL " .. message)
	end
end

local function section(name)
	out("\n== " .. name)
end

local function noErrors(W, label)
	local detail = ""
	if #W.errors > 0 then
		detail = ": " .. W.errors[1]
	elseif #W.blocked > 0 then
		detail = ": blocked " .. W.blocked[1]
	end
	check(#W.errors == 0 and #W.blocked == 0, label .. detail)
end

local function fresh(setup)
	package.loaded.wow_stub = nil
	ForeverDruidCharDB, ForeverDruidProbe, ForeverDruidDB = nil, nil, nil
	local W = require("wow_stub")
	if setup then
		setup(W)
	end
	local ns = W.LoadAddon("ForeverDruid", "ForeverDruid")
	return W, ns
end

local function login(W)
	W.Fire("ADDON_LOADED", "ForeverDruid")
	W.Fire("PLAYER_LOGIN")
	W.Fire("PLAYER_ENTERING_WORLD", true, false)
	W.Advance(1)
end

local function labels(list)
	local set = {}
	for _, r in ipairs(list) do
		set[r.label] = true
	end
	return set
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("login: feral-specced Skyborne druid in caster form")
	login(W)
	noErrors(W, "no Lua errors on login")
	check(ns.isDruid, "detects druid")
	check(ns.profileName == "Default", "uses the Default profile")
	check(ns.tree == "feral" and ns.role == "feral", ("talent line feral, role feral (got %s/%s)"):format(tostring(ns.tree), tostring(ns.role)))
	check(ns.KnownSpell("readLeyline") == 1259705, "finds Forever's Read Leyline (1259705)")
	check(not ns.modules.manabar.bar:IsShown(), "mana bar hidden in caster form")
	check(ns.global.lastVersion == ns.VERSION, "records the version for the update notice")

	local reminders = ns.modules.reminders
	local set = labels(reminders.active)
	check(set["Mark"], "reminds about Mark of the Wild")
	check(set["Seeds 0"], "reminds about Rebirth seeds")
	check(set["Ley line"], "Skyborne: reminds to attune at a ley line")
	check(not set["Thorns"], "no Thorns reminder outside Bear Form by default")

	local markButton
	for i, item in ipairs(reminders.active) do
		if item.label == "Mark" then
			markButton = _G["ForeverDruidReminder" .. i]
		end
	end
	check(markButton and markButton:GetAttribute("type") == "spell" and markButton:GetAttribute("spell") == "Mark of the Wild",
		"Mark reminder is a click-to-cast button for Mark of the Wild")

	W.state.auras["Mark of the Wild"] = { spellId = 5232, duration = 1800, expirationTime = W.now + 1800 }
	W.state.auras["Attuned"] = { spellId = 1259691, duration = 3600, expirationTime = W.now + 3600 }
	W.state.items[17034] = 5
	W.Fire("UNIT_AURA", "player", {})
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(1)
	check(#reminders.active == 0, "reminders clear once buffed, attuned and stocked (" .. #reminders.active .. " left)")

	section("Cat Form: mana bar, combo points, energy ticks from event timing")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.1)
	check(ns.form == "cat" and ns.role == "cat", "form/role = cat")
	local manabar = ns.modules.manabar
	check(manabar.bar:IsShown(), "mana bar shown in Cat Form")
	check(manabar.text:GetText() == "<secret text>", "mana text formatted by the client from secret values")
	check(manabar.marker:IsShown(), "powershift cost marker shown (cost 400 of 4000)")
	check(manabar.bar._color and #manabar.bar._color == 3, "mana bar coloured through the curve")

	W.state.power[4] = 3
	W.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	local combo = ns.modules.combopoints
	check(combo.anchor:IsShown(), "combo points shown in Cat Form")

	local cooldowns = ns.modules.cooldowns
	check(cooldowns.count == 8, "cat row: 6 cat spells + 2 Skyborne racials (got " .. tostring(cooldowns.count) .. ")")

	-- Ticks every 2.0s; a Shred at +0.6s after the third tick produces an energy event right after
	-- the cast, which must be ignored.
	local tick = ns.modules.energytick
	local base = W.now
	local function advanceTo(t)
		W.Advance(t - W.now)
	end
	for i = 1, 6 do
		advanceTo(base + 2.0 * i)
		W.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
		if i == 3 then
			advanceTo(base + 2.0 * i + 0.6)
			W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 5221)
			advanceTo(base + 2.0 * i + 0.65)
			W.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
		end
	end
	local stats = ns.energyTickStats
	check(stats.mode == "tick", "energy regen classified as ticks from event timing (mode=" .. tostring(stats.mode) .. ")")
	check(math.abs(stats.period - 2.0) < 0.05, ("tick period ~2.0s (got %.3f)"):format(stats.period))
	check(stats.castEvents == 1, "the energy event right after a cast was ignored")
	check(tick.bar:IsShown(), "tick bar shown in Cat Form once learned")

	section("combat: auras go secret, power stays secret")
	W.state.auras["Clearcasting"] = { spellId = 16870, duration = 15, expirationTime = W.now + 15 }
	W.state.auras["Tiger's Fury"] = { spellId = 5217, duration = 6, expirationTime = W.now + 6 }
	W.Fire("UNIT_AURA", "player", {})
	W.Advance(0.2)
	local buffs = ns.modules.buffs
	local before = {}
	for _, item in ipairs(buffs.active) do
		before[item.key] = true
	end
	check(before.clearcasting and before.tigersFury, "buffs: Clearcasting and Tiger's Fury shown out of combat")

	W.state.targetExists = true
	W.state.targetHostile = true
	W.state.targetAuras = {
		{ icon = 132152, expirationTime = W.now + 9, duration = 9, applications = 0, auraInstanceID = 501 },
		{ icon = 132122, expirationTime = W.now + 12, duration = 12, applications = 0, auraInstanceID = 502 },
	}
	W.Fire("PLAYER_TARGET_CHANGED")
	W.Advance(0.2)
	local target = ns.modules.targetauras
	check(target.stats.shown == 2, "target: two of my debuffs shown (got " .. tostring(target.stats.shown) .. ")")

	-- The client fires PLAYER_REGEN_DISABLED just before lockdown starts.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.state.secretAuras = true
	W.Fire("UNIT_POWER_FREQUENT", "player", "MANA")
	W.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
	W.Fire("UNIT_MAXPOWER", "player")
	W.Fire("SPELL_UPDATE_COOLDOWN")
	W.Fire("UNIT_AURA", "player", {})
	W.Fire("UNIT_AURA", "target", {})
	W.Advance(3)
	noErrors(W, "no Lua errors or blocked actions in combat")
	check(cooldowns.stats.durationCalls > 0 and cooldowns.stats.durationFailures == 0, "cooldowns drawn from duration objects")
	local during = {}
	for _, item in ipairs(buffs.active) do
		during[item.key] = item.stale and "stale" or "live"
	end
	check(during.clearcasting == "live", "Clearcasting still readable in combat (whitelisted aura)")
	check(during.tigersFury == "stale", "Tiger's Fury kept, dimmed, when the client refuses the lookup")
	check(target.stats.shown == 2, "target debuffs still drawn from secret fields in combat")
	check(#reminders.active == 0, "reminders hidden in combat")
	check(tick.bar._values.value ~= nil, "tick spark keeps moving in combat")

	W.Advance(5) -- Tiger's Fury (6s) has now expired
	W.Fire("UNIT_AURA", "player", {})
	W.Advance(0.2)
	local after = {}
	for _, item in ipairs(buffs.active) do
		after[item.key] = true
	end
	check(not after.tigersFury, "stale Tiger's Fury dropped once its timer ran out")

	check(ForeverDruidProbe and #ForeverDruidProbe.snapshots >= 2, "probe auto-snapshots at login and first combat")
	local snaps = ForeverDruidProbe and ForeverDruidProbe.snapshots or {}
	local snap = snaps[#snaps] or { power = { mana = {} } }
	check(snap.tag == "combat" and snap.power.mana.value == "<secret>", "combat snapshot records mana as <secret>")
	check(snap.auraSecrecy and snap.auraSecrecy.clearcasting and snap.auraSecrecy.clearcasting.secret == false, "probe records per-aura secrecy")
	check(snap.moduleStats and snap.moduleStats.targetauras, "probe records module stats")

	W.Slash("unlock")
	check(not ns.db.unlocked, "unlock refused during combat")

	section("leave combat, Bear Form")
	W.state.inCombat = false
	W.state.secretAuras = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(1)
	check(ns.role == "bear", "role = bear")
	check(cooldowns.count == 6, "bear row: Enrage, Barkskin, Innervate, Rebirth + 2 racials (got " .. tostring(cooldowns.count) .. ")")
	check(not tick.bar:IsShown(), "tick bar hidden outside Cat Form")
	check(labels(reminders.active)["Thorns"], "Thorns reminder in Bear Form")

	section("mounting hides the HUD")
	W.state.mounted = true
	W.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	W.Advance(0.2)
	check(not ns.root:IsShown(), "root hidden while mounted")
	W.state.mounted = false
	W.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	W.Advance(0.2)
	check(ns.root:IsShown(), "root shown again after dismounting")

	section("slash commands, custom cooldowns, profiles, options panel")
	for _, cmd in ipairs({ "", "help", "status", "unlock", "lock", "reset", "toggle manabar", "toggle manabar",
		"toggle nope", "cd add all Nature's Grasp", "cd add bear Growl", "cd list", "cd remove bear Growl", "cd add moon Wrath",
		"probe", "config", "profile", "profile list" }) do
		W.Slash(cmd)
	end
	W.Advance(0.5)
	noErrors(W, "all slash commands run cleanly")
	check(ns.db.modules.manabar.enabled == true, "toggle twice leaves the mana bar on")
	check(#ns.db.modules.cooldowns.extra.all == 1, "custom cooldown stored")
	check(ns.db.unlocked == false, "lock state restored")
	check(W.ShowOptionsPanel(), "options panel registered and shown")
	noErrors(W, "options panel widgets refresh cleanly")

	W.Slash("profile use Tank")
	check(ns.global.chars[ns.charKey] == "Tank" and ns.global.profiles.Tank, "profile switch recorded for next load")
	W.Slash("profile copy Default")
	W.Slash("profile delete Default")
	check(ns.global.profiles.Default ~= nil, "the active profile can't be deleted")
	W.Slash("profile delete Tank")
	check(ns.global.profiles.Tank == nil and ns.global.chars[ns.charKey] == "Default", "deleting another profile moves its characters to Default")

	ForeverDruid_OnAddonCompartmentClick(nil, "RightButton")
	check(ns.db.unlocked == true, "addon compartment right-click unlocks")
	ForeverDruid_OnAddonCompartmentClick(nil, "RightButton")
	ForeverDruid_OnAddonCompartmentClick(nil, "LeftButton")
	noErrors(W, "addon compartment entry works")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("continuous energy regen is detected and the tick bar stays hidden")
	login(W)
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.1)
	for _ = 1, 20 do
		W.Advance(0.1)
		W.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
	end
	check(ns.energyTickStats.mode == "continuous", "mode = continuous (got " .. tostring(ns.energyTickStats.mode) .. ")")
	check(not ns.modules.energytick.bar:IsShown(), "tick bar hidden for continuous regen")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("friendly target shows my HoTs; restoration role; missing talent API")
	W.state.trees = { { "Balance", 0 }, { "Feral Combat", 0 }, { "Restoration", 31 } }
	login(W)
	check(ns.role == "healer", "resto points -> healer role (got " .. tostring(ns.role) .. ")")
	W.state.targetExists = true
	W.state.targetHostile = false
	W.state.targetAuras = { { icon = 136081, expirationTime = W.now + 12, duration = 12, applications = 0, auraInstanceID = 9 } }
	W.Fire("PLAYER_TARGET_CHANGED")
	W.Advance(0.2)
	check(ns.modules.targetauras.stats.shown == 1, "my Rejuvenation on a friendly target is shown")
	C_Traits = nil
	W.Fire("TRAIT_CONFIG_UPDATED")
	W.Advance(0.2)
	check(ns.role == "caster", "falls back to caster role without talent data (got " .. tostring(ns.role) .. ")")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("review regressions: combat state inside PLAYER_REGEN_DISABLED, deferred hides, secret combo points")
	login(W)
	ns.db.fadeOutOfCombat = 0.3
	ns.db.modules.cooldowns.hideOutOfCombat = true
	ns.UpdateVisibility()
	ns.modules.cooldowns:Refresh()
	local manaAnchor = ns.anchors.manabar
	check(manaAnchor:GetAlpha() == 0.3, "HUD faded to 0.3 out of combat")
	check(not ns.modules.cooldowns.anchor:IsShown(), "cooldowns hidden out of combat when asked")

	-- InCombatLockdown() is still false while PLAYER_REGEN_DISABLED handlers run.
	W.Fire("PLAYER_REGEN_DISABLED")
	check(manaAnchor:GetAlpha() == 1, "HUD at full opacity as combat starts")
	check(ns.modules.cooldowns.anchor:IsShown(), "cooldowns shown as combat starts")
	W.state.inCombat = true

	W.Slash("toggle reminders")
	check(ns.modules.reminders.hideAfterCombat, "disabling reminders in combat defers the hide")
	W.state.power[4] = nil
	local realGetComboPoints = GetComboPoints
	GetComboPoints = function()
		return W.Secret()
	end
	W.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	check(ns.modules.combopoints.text:GetText() == "<secret text>", "secret combo points shown as client-formatted text")
	GetComboPoints = realGetComboPoints
	W.Advance(1)
	noErrors(W, "no errors or blocked actions")

	-- PLAYER_REGEN_ENABLED fires after lockdown has ended.
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(0.5)
	check(not ns.modules.reminders.anchor:IsShown(), "reminders hidden once combat ended")
	check(manaAnchor:GetAlpha() == 0.3, "HUD fades again after combat")
	noErrors(W, "no blocked actions after combat")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("/reload in the middle of combat")
	W.state.inCombat = true
	W.state.secretAuras = true
	login(W)
	W.Advance(1)
	noErrors(W, "login under combat lockdown creates no secure frames and errors nothing")
	check(#ns.modules.reminders.active == 0, "reminders wait for combat to end")
	W.state.inCombat = false
	W.state.secretAuras = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(1)
	check(#ns.modules.reminders.active > 0, "reminders appear once combat ends")
	noErrors(W, "no blocked actions after combat")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh(function(W)
		ForeverDruidCharDB = { modules = { manabar = { width = 222 } }, unlocked = false, positions = {} }
	end)
	section("upgrade from v0.1.0 per-character settings")
	login(W)
	check(ns.db.modules.manabar.width == 222, "old per-character settings carried into the profile")
	check(ForeverDruidCharDB == nil, "legacy per-character table cleared")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh(function(W)
		W.state.class = "WARLOCK"
		W.unknownEvents = { LEARNED_SPELL_IN_SKILL_LINE = true, PLAYER_CONTROL_LOST = true }
	end)
	section("non-druid: modules stay off, probe still works, unknown events tolerated")
	login(W)
	W.Slash("probe")
	W.Advance(6)
	noErrors(W, "no errors on a warlock")
	check(not ns.modules.manabar.initialized, "druid modules not initialised")
	check(ForeverDruidProbe and #ForeverDruidProbe.snapshots >= 1, "manual probe recorded")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("automatic stack: one column that closes up and moves as one")
	login(W)
	local A = ns.anchors
	local function hangsFrom(key)
		local point, relativeTo, relativePoint, _, y = A[key]:GetPoint()
		return relativeTo, point, relativePoint, y
	end
	-- Which shown pieces hang from which, top to bottom.
	local function chain()
		local names = {}
		for _, key in ipairs(ns.STACK_ORDER) do
			if A[key] and A[key]:IsShown() and ns.IsStacked(A[key]) then
				names[#names + 1] = key
			end
		end
		return table.concat(names, ",")
	end
	local function linked()
		local previous = ns.stackHead
		for _, key in ipairs(ns.STACK_ORDER) do
			local a = A[key]
			if a and a:IsShown() and ns.IsStacked(a) then
				local rel, point, relPoint = hangsFrom(key)
				if rel ~= previous or point ~= "TOP" then
					return false, key
				end
				if previous ~= ns.stackHead and relPoint ~= "BOTTOM" then
					return false, key
				end
				previous = a
			end
		end
		return true
	end

	check(chain() == "targetauras,cooldowns,buffs", "caster form: mana bar, tick and combo rows take no room (" .. chain() .. ")")
	local ok, bad = linked()
	check(ok, "caster form: each piece hangs from the one above it" .. (bad and (" (" .. bad .. ")") or ""))

	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(chain():find("targetauras,manabar,", 1, true) == 1 and chain():find("combopoints,cooldowns,buffs", 1, true),
		"Cat Form: mana bar and combo points slot in (" .. chain() .. ")")
	ok, bad = linked()
	check(ok, "Cat Form: column re-chained" .. (bad and (" (" .. bad .. ")") or ""))

	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(chain() == "targetauras,manabar,cooldowns,buffs", "Bear Form: combo points and tick close up (" .. chain() .. ")")
	ok, bad = linked()
	check(ok, "Bear Form: no gaps" .. (bad and (" (" .. bad .. ")") or ""))

	W.Slash("toggle manabar")
	check(chain() == "targetauras,cooldowns,buffs", "disabling a module closes its gap")
	W.Slash("toggle manabar")
	check(chain() == "targetauras,manabar,cooldowns,buffs", "re-enabling slots it back in")

	-- Resizing needs no re-layout: pieces hang from the bottom edge of the one above.
	ns.db.modules.cooldowns.size = 48
	ns.modules.cooldowns:Refresh()
	local rel = hangsFrom("buffs")
	check(rel == A.cooldowns, "bigger cooldown icons push buffs down instead of overlapping")

	W.Slash("unlock")
	local _, _, _, gapUnlocked = hangsFrom("cooldowns")
	check(gapUnlocked == -(ns.db.layout.gap + 12), "unlocked: extra room for each piece's name")
	check(chain() == "targetauras,manabar,energytick,combopoints,cooldowns,buffs", "unlocked: every piece shown in the column")

	-- A plain drag of any stacked piece moves the whole column.
	A.manabar:GetScript("OnDragStart")(A.manabar)
	check(rawget(ns.stackHead, "_moving") and not rawget(A.manabar, "_moving"), "dragging a stacked piece moves the column")
	ns.stackHead._points = { { "CENTER", ns.root, "CENTER", 40, -90 } }
	A.manabar:GetScript("OnDragStop")(A.manabar)
	check(ns.db.positions.stack and ns.db.positions.stack[3] == 40 and not ns.db.positions.manabar,
		"the column's position is saved, not the piece's")

	-- Shift-drag pulls one piece out; the rest close up behind it.
	W.state.shift = true
	A.combopoints:GetScript("OnDragStart")(A.combopoints)
	W.state.shift = false
	check(ns.db.layout.detached.combopoints and rawget(A.combopoints, "_moving"), "shift-drag detaches the piece being dragged")
	A.combopoints._points = { { "CENTER", ns.root, "CENTER", 200, 0 } }
	A.combopoints:GetScript("OnDragStop")(A.combopoints)
	check(hangsFrom("cooldowns") == A.energytick, "the column closes up behind a detached piece")
	check(ns.db.positions.combopoints and ns.db.positions.combopoints[3] == 200, "the detached piece keeps its own spot")
	W.Slash("lock")

	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(hangsFrom("combopoints") == ns.root, "a detached piece stays put through form changes")

	check(W.ShowOptionsPanel(), "options panel with stack settings shows")
	ns.SetStacked("combopoints", true)
	check(not ns.db.layout.detached.combopoints and hangsFrom("combopoints") ~= ns.root, "\"Part of the stack\" puts it back")

	-- Combat: forms change mid-fight; the column must re-chain without any blocked action.
	W.Fire("PLAYER_REGEN_DISABLED") -- the client fires this just before lockdown starts
	W.state.inCombat = true
	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	ok, bad = linked()
	check(ok and chain() == "targetauras,manabar,cooldowns,buffs", "re-chains in combat (" .. chain() .. ")")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")

	W.Slash("stack off")
	check(ns.db.layout.stack == false and hangsFrom("cooldowns") == ns.root, "/fd stack off: pieces go back to their own spots")
	W.Slash("stack on")
	check(hangsFrom("cooldowns") ~= ns.root, "/fd stack on: stacked again")

	ns.db.layout.detached.buffs = true
	W.Slash("reset")
	check(next(ns.db.layout.detached) == nil and next(ns.db.positions) == nil, "/fd reset re-attaches everything and clears positions")
	check(hangsFrom("targetauras") == ns.stackHead, "after reset the column hangs from its default point")
	noErrors(W, "no errors or blocked actions")
end

---------------------------------------------------------------------------
do
	section("Omen of Clarity: passive talent on Forever, castable buff elsewhere")
	local W, ns = fresh(function(W)
		table.insert(W.state.spellbook, { 16864, "Omen of Clarity", passive = true })
	end)
	login(W)
	check(ns.IsKnown("omenOfClarity") and not ns.IsCastable("omenOfClarity"), "a passive Omen counts as known but not castable")
	check(not labels(ns.modules.reminders.active)["Omen"], "no Omen reminder when it's a passive talent")

	local W2, ns2 = fresh(function(W)
		table.insert(W.state.spellbook, { 16864, "Omen of Clarity" })
	end)
	login(W2)
	check(labels(ns2.modules.reminders.active)["Omen"], "Omen reminder still offered where it's a castable buff")
	noErrors(W, "no errors")
	noErrors(W2, "no errors")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("minimap button and quick settings menu")
	login(W)
	local button = _G.ForeverDruidMinimapButton
	check(button and button:IsShown(), "druid gets a minimap button")
	local _, rel, _, x, y = button:GetPoint()
	check(rel == Minimap and math.abs(math.sqrt(x * x + y * y) - 75) < 0.01, "sits on the minimap ring (radius 75)")

	-- Drag round the ring: cursor straight above the minimap centre -> 90 degrees.
	W.cursor = { 1000, 800 }
	button:GetScript("OnDragStart")(button)
	button:GetScript("OnUpdate")(button, 0.02)
	button:GetScript("OnDragStop")(button)
	_, _, _, x, y = button:GetPoint()
	check(math.abs(ns.db.minimap.angle - 90) < 0.01 and math.abs(x) < 0.01 and math.abs(y - 75) < 0.01,
		"dragging moves it round the ring and saves the angle")
	check(button:GetScript("OnUpdate") == nil, "stops following the cursor on release")

	button:GetScript("OnClick")(button, "LeftButton")
	local menu = W.lastMenu
	check(menu and menu:Find("ForeverDruid"), "left-click opens the quick menu")

	local entry = menu:Find("Show", "Combo points")
	check(entry and entry:Selected(), "Show > Combo points is ticked")
	entry:Click()
	check(not ns.db.modules.combopoints.enabled and not ns.anchors.combopoints:IsShown(), "unticking turns combo points off")
	entry:Click()
	check(ns.db.modules.combopoints.enabled, "ticking turns them back on")

	menu:Find("HUD size", "125%"):Click()
	check(ns.db.scale == 1.25 and rawget(ns.root, "_scale") == 1.25, "HUD size 125% applies")
	check(menu:Find("HUD size", "125%"):Selected() and not menu:Find("HUD size", "100%"):Selected(), "size radio shows the current choice")

	menu:Find("Out of combat", "Faded"):Click()
	check(ns.db.fadeOutOfCombat == 0.6 and ns.anchors.cooldowns:GetAlpha() == 0.6, "fade out of combat applies")

	menu:Find("Reminders", "Thorns", "Always"):Click()
	check(ns.db.modules.reminders.thorns == true, "Thorns: Always")
	menu:Find("Reminders", "Thorns", "Never"):Click()
	check(not ns.db.modules.reminders.thorns and not ns.db.modules.reminders.thornsInBear, "Thorns: Never")
	check(menu:Find("Reminders", "Thorns", "Never"):Selected(), "Thorns radio reflects the setting")

	menu:Find("Forms", "Mana bar text", "percent"):Click()
	check(ns.db.modules.manabar.text == "percent", "mana bar text from the menu")

	menu:Find("Unlock to move"):Click()
	check(ns.db.unlocked, "menu unlock")
	menu:Find("Unlock to move"):Click()
	check(not ns.db.unlocked, "menu lock")

	button:GetScript("OnClick")(button, "RightButton")
	check(ns.db.unlocked, "right-click unlocks")
	button:GetScript("OnClick")(button, "RightButton")

	W.state.shift = true
	W.lastMenu = nil
	button:GetScript("OnClick")(button, "LeftButton")
	W.state.shift = false
	check(W.lastMenu == nil, "shift-click opens the full settings instead of the menu")

	ForeverDruid_OnAddonCompartmentClick("ForeverDruid", "LeftButton", UIParent)
	check(W.lastMenu and W.lastMenu:Find("Show"), "the addon menu entry opens the same quick menu")

	menu:Find("Profile", "Reload now"):Click()
	check(W.reloaded, "profile submenu can reload")

	menu:Find("Hide this minimap button"):Click()
	check(ns.db.minimap.hide and not button:IsShown(), "hide from the menu")
	W.Slash("minimap")
	check(not ns.db.minimap.hide and button:IsShown(), "/fd minimap brings it back")
	check(W.ShowOptionsPanel(), "options panel with the minimap setting shows")
	noErrors(W, "no errors or blocked actions")

	-- Hidden at login: no button until asked for.
	_G.ForeverDruidMinimapButton = nil
	local W2, ns2 = fresh(function(W)
		ForeverDruidDB = { profiles = { Default = { minimap = { hide = true, angle = 10 } } }, chars = {} }
	end)
	login(W2)
	check(_G.ForeverDruidMinimapButton == nil or not _G.ForeverDruidMinimapButton:IsShown(), "stays hidden across reloads when hidden")
	noErrors(W2, "no errors")
end

do
	local W, ns = fresh(function(W)
		W.state.class = "WARLOCK"
	end)
	section("non-druid: no minimap button")
	_G.ForeverDruidMinimapButton = nil
	login(W)
	check(_G.ForeverDruidMinimapButton == nil, "no minimap button on a warlock")
	noErrors(W, "no errors")
end

out(("\n%s (%d failure%s)"):format(failures == 0 and "PASS" or "FAIL", failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
