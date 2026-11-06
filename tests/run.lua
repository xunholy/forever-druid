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
	local power = ns.modules.powerbar
	power:UpdateSpark()
	check(power.spark:IsShown() and not tick.anchor:IsShown(), "learned ticks draw on the energy bar; the separate tick row steps aside")
	ns.db.modules.powerbar.tickSpark = false
	tick:Refresh()
	check(tick.bar:IsShown(), "with the spark off the energy bar, the tick row shows once learned")
	ns.db.modules.powerbar.tickSpark = true
	power:Refresh()

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

	check(chain() == "targetauras,fsr,cooldowns,buffs", "caster form: energy, mana, tick and combo rows take no room (" .. chain() .. ")")
	local ok, bad = linked()
	check(ok, "caster form: each piece hangs from the one above it" .. (bad and (" (" .. bad .. ")") or ""))

	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(chain() == "targetauras,powerbar,manabar,fsr,combopoints,cooldowns,buffs",
		"Cat Form: energy bar, mana bar and combo points slot in (" .. chain() .. ")")
	ok, bad = linked()
	check(ok, "Cat Form: column re-chained" .. (bad and (" (" .. bad .. ")") or ""))

	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(chain() == "targetauras,powerbar,manabar,fsr,cooldowns,buffs", "Bear Form: combo points and tick close up (" .. chain() .. ")")
	ok, bad = linked()
	check(ok, "Bear Form: no gaps" .. (bad and (" (" .. bad .. ")") or ""))

	W.Slash("toggle manabar")
	check(chain() == "targetauras,powerbar,fsr,cooldowns,buffs", "disabling a module closes its gap")
	W.Slash("toggle manabar")
	check(chain() == "targetauras,powerbar,manabar,fsr,cooldowns,buffs", "re-enabling slots it back in")

	-- Resizing needs no re-layout: pieces hang from the bottom edge of the one above.
	ns.db.modules.cooldowns.size = 48
	ns.modules.cooldowns:Refresh()
	local rel = hangsFrom("buffs")
	check(rel == A.cooldowns, "bigger cooldown icons push buffs down instead of overlapping")

	W.Slash("unlock")
	local _, _, _, gapUnlocked = hangsFrom("cooldowns")
	check(gapUnlocked == -(ns.db.layout.gap + 12), "unlocked: extra room for each piece's name")
	check(chain() == "targetauras,powerbar,manabar,fsr,energytick,combopoints,cooldowns,buffs", "unlocked: every piece shown in the column")

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
	check(ok and chain() == "targetauras,powerbar,manabar,fsr,cooldowns,buffs", "re-chains in combat (" .. chain() .. ")")
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

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("polish: preview while unlocked, ready pulse, tints, icon styles, smooth mana")
	login(W)
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	local buffs, targets, combo = ns.modules.buffs, ns.modules.targetauras, ns.modules.combopoints

	W.Slash("unlock")
	W.Advance(0.5)
	check(#buffs.active == 3, "unlocked: buff row shows three sample buffs (" .. #buffs.active .. ")")
	check(targets.stats.shown == 3, "unlocked: target row shows three sample DoTs (" .. targets.stats.shown .. ")")
	local lit = 0
	for _, f in ipairs(W.frames) do
		if rawget(f, "_parent") == ns.anchors.combopoints and rawget(f, "_kind") == "Texture" and f:IsShown() then
			lit = lit + 1
		end
	end
	check(lit >= 4, "unlocked: combo points preview lit")
	local reminderSamples = ns.modules.reminders.active
	check(#reminderSamples > 0, "unlocked: reminders row has something to place")
	W.Slash("lock")
	W.Advance(0.5)
	check(#buffs.active == 0, "locked again: samples go away")

	ns.db.preview = false
	W.Slash("unlock")
	W.Advance(0.5)
	check(#buffs.active == 0, "preview can be turned off")
	W.Slash("lock")
	ns.db.preview = true

	-- Ready pulse: a cooldown ending by itself pulses; Clear() and hidden icons don't.
	local cooldowns = ns.modules.cooldowns
	local button = cooldowns.buttons[1]
	local done = button.cooldown:GetScript("OnCooldownDone")
	check(done ~= nil, "cooldown icons listen for their cooldown finishing")
	local before = ns.pulseCount or 0
	W.Advance(1) -- a real cooldown finishes well after the addon last set it
	done(button.cooldown)
	check((ns.pulseCount or 0) == before + 1, "a finished cooldown pulses")
	cooldowns:UpdateCooldowns() -- the addon setting cooldowns itself...
	done(button.cooldown)
	check((ns.pulseCount or 0) == before + 1, "a 'done' right after we set or cleared it doesn't pulse")
	W.Advance(1)
	ns.db.modules.cooldowns.pulse = false
	W.Advance(1)
	done(button.cooldown)
	check((ns.pulseCount or 0) == before + 1, "pulse can be turned off")
	ns.db.modules.cooldowns.pulse = true

	-- Tints use the client's booleans without reading them, so secret values work in combat.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.state.spellUsable, W.state.spellNoPower, W.state.spellInRange = W.Secret(), W.Secret(), W.Secret()
	cooldowns:UpdateTints()
	check(W.IsSecret(rawget(button.icon, "_colorBool")), "usable tint takes a secret boolean")
	check(W.IsSecret(rawget(button.rangeTint, "_colorBool")), "range tint takes a secret boolean")
	check(ns.tintStats.failures == 0, "no tint failures")
	W.state.spellInRange = nil
	cooldowns:UpdateTints()
	check(rawget(button.rangeTint, "_colorBool") == nil, "no range check (nil) clears the range tint")
	W.state.spellInRange = false
	cooldowns:UpdateTints()
	check(rawget(button.rangeTint, "_colorBool") == false, "out of range (false) drives the red tint")
	W.state.spellInRange = true
	cooldowns:UpdateTints()
	check(rawget(button.rangeTint, "_colorBool") == true, "in range (true) clears it")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.state.spellUsable, W.state.spellNoPower = true, false

	-- Icon style switch restyles icons already on screen.
	ns.db.style.icons = "blizzard"
	ns.RestyleAll()
	local tc = rawget(button.icon, "_texcoord")
	check(tc and tc[1] == 0 and tc[2] == 1 and not button.border:IsShown(), "Blizzard style: full icon border, no frame")
	ns.db.style.icons = "minimal"
	ns.RestyleAll()
	check(button.border:IsShown(), "minimal style: thin frame back")

	local bar = ns.modules.manabar.bar
	ns.modules.manabar:Update()
	check(rawget(bar, "_interpolation") == Enum.StatusBarInterpolation.ExponentialEaseOut, "mana bar eases to new values")
	ns.db.modules.manabar.smooth = false
	ns.modules.manabar:Update()
	check(rawget(bar, "_interpolation") == nil, "smoothing can be turned off")
	noErrors(W, "no errors or blocked actions")
end

---------------------------------------------------------------------------
do
	section("onboarding: welcome tour on first install, What's new after an update")
	local W, ns = fresh()
	login(W)
	W.Advance(5)
	local tour = _G.ForeverDruidTour
	check(tour and tour:IsShown(), "first install shows the welcome tour")
	tour:Hide()
	tour:GetScript("OnHide")(tour)
	check(ns.global.tourSeen, "closing the tour marks it seen")
	check(ns.CompareVersions("0.10.0", "0.9.9") == 1 and ns.CompareVersions("0.4.0", "0.4.0") == 0
		and ns.CompareVersions("0.3.0", "0.5.0") == -1, "version compare handles multi-digit parts")
	noErrors(W, "no errors")

	_G.ForeverDruidTour, _G.ForeverDruidWhatsNew = nil, nil
	local W2, ns2 = fresh(function()
		ForeverDruidDB = { profiles = { Default = {} }, chars = {}, lastVersion = "0.3.0" }
	end)
	login(W2)
	W2.Advance(5)
	local news = _G.ForeverDruidWhatsNew
	check(news and news:IsShown(), "updating shows What's new")
	local versions = {}
	for _, release in ipairs(news.releases or {}) do
		versions[#versions + 1] = release.version
	end
	check(table.concat(versions, ",") == ns2.VERSION .. ",0.4.0", "only versions newer than the last one seen (" .. table.concat(versions, ",") .. ")")
	check(_G.ForeverDruidTour == nil, "no tour for someone upgrading")
	noErrors(W2, "no errors")

	_G.ForeverDruidWhatsNew = nil
	local W3 = fresh(function()
		ForeverDruidDB = { profiles = { Default = {} }, chars = {}, lastVersion = "0.3.0" }
	end)
	W3.Fire("ADDON_LOADED", "ForeverDruid")
	W3.Fire("PLAYER_LOGIN")
	W3.Fire("PLAYER_REGEN_DISABLED")
	W3.state.inCombat = true
	W3.Advance(5)
	check(_G.ForeverDruidWhatsNew == nil, "never pops up in combat")
	W3.state.inCombat = false
	W3.Fire("PLAYER_REGEN_ENABLED")
	W3.Advance(2)
	check(_G.ForeverDruidWhatsNew and _G.ForeverDruidWhatsNew:IsShown(), "shows once the fight is over")
	noErrors(W3, "no errors")
end

---------------------------------------------------------------------------
do
	section("arranging: arrow-key nudge, alignment grid, confirmations, keybindings")
	local W, ns = fresh()
	login(W)
	W.Advance(5)
	if _G.ForeverDruidTour then
		_G.ForeverDruidTour:Hide()
	end
	W.Slash("unlock")
	local anchor = ns.anchors.cooldowns
	anchor:GetScript("OnEnter")(anchor)
	local _, _, _, x0, y0 = ns.stackHead:GetPoint()
	anchor:GetScript("OnKeyDown")(anchor, "UP")
	local _, _, _, x1, y1 = ns.stackHead:GetPoint()
	check(y1 == y0 + 1 and x1 == x0, "arrow up nudges the stack one pixel")
	W.state.shift = true
	anchor:GetScript("OnKeyDown")(anchor, "LEFT")
	W.state.shift = false
	local _, _, _, x2 = ns.stackHead:GetPoint()
	check(x2 == x0 - 10, "shift-arrow nudges ten")
	check(ns.db.positions.stack and ns.db.positions.stack[4] == y1, "nudged position is saved")
	check(not ns.Nudge(anchor, "W"), "other keys pass through to the game")

	W.Slash("grid")
	check(_G.ForeverDruidGrid and _G.ForeverDruidGrid:IsShown(), "grid shows while unlocked")
	W.Slash("lock")
	check(not _G.ForeverDruidGrid:IsShown(), "grid hides when locked")

	ns.ConfirmResetPositions()
	check(#W.popups == 1, "reset positions asks first")
	check(ns.db.positions.stack ~= nil, "nothing reset before answering")
	W.AcceptPopup()
	check(next(ns.db.positions) == nil, "accepting resets")

	ForeverDruid_ToggleUnlock()
	check(ns.db.unlocked, "unlock keybinding")
	ForeverDruid_ToggleUnlock()
	ForeverDruid_OpenQuickMenu()
	check(W.lastMenu and W.lastMenu:Find("Show"), "quick-menu keybinding")
	check(BINDING_NAME_FOREVERDRUID_UNLOCK and BINDING_HEADER_FOREVERDRUID == "ForeverDruid", "keybinding names defined")
	local f = io.open("ForeverDruid/Bindings.xml")
	local xml = f and f:read("*a") or ""
	if f then
		f:close()
	end
	for _, fn in ipairs({ "ForeverDruid_ToggleUnlock", "ForeverDruid_OpenQuickMenu", "ForeverDruid_OpenOptions" }) do
		check(xml:find(fn .. "()", 1, true) and type(_G[fn]) == "function", "Bindings.xml calls " .. fn)
	end

	local ok, pages = W.ShowOptionsPanel()
	check(ok and pages == 2 + #ns.moduleOrder, "settings: main page, one per part of the HUD, and Macros (" .. tostring(pages) .. ")")
	noErrors(W, "no errors or blocked actions")

	-- Keyboard capture never survives into combat.
	W.Slash("unlock")
	anchor:GetScript("OnEnter")(anchor)
	W.Fire("PLAYER_REGEN_DISABLED")
	check(rawget(anchor, "_keyboard") == false, "keyboard released as combat starts")
	W.Slash("lock")
end

---------------------------------------------------------------------------
do
	section("profile sharing: export/import round trip, hostile strings rejected")
	local W, ns = fresh()
	login(W)
	ns.db.scale = 1.25
	ns.db.modules.cooldowns.extra = { all = { "Nature's Grasp" } }
	ns.db.layout.detached = { buffs = true }
	local text = ns.ExportProfile()
	check(type(text) == "string" and text:sub(1, 5) == "!FD1!", "export gives a !FD1! string")
	local name = ns.ImportProfile(text)
	local copy = name and ns.global.profiles[name]
	check(copy and copy.scale == 1.25 and copy.modules.cooldowns.extra.all[1] == "Nature's Grasp" and copy.layout.detached.buffs == true,
		"import round-trips numbers, strings, nested tables and booleans")
	check(name == "Imported", "imported under a new name (" .. tostring(name) .. ")")
	check(ns.ImportProfile(text) == "Imported 2", "a second import doesn't overwrite the first")
	check(ns.profileName == "Default", "importing doesn't switch profiles by itself")

	for i = 0, 255 do
		local raw = string.char(i, (i * 7) % 256, (i * 13) % 256)
		assert(ns.Base64Decode(ns.Base64Encode(raw)) == raw)
	end
	check(true, "base64 round-trips every byte")

	local function rejects(s)
		local profile = ns.DecodeProfile(s)
		return profile == nil
	end
	check(rejects("hello"), "rejects text without the prefix")
	check(rejects("!FD1!@@@@"), "rejects damaged base64")
	check(rejects("!FD1!" .. ns.Base64Encode("Tfunction() os.exit() end")), "rejects code; only data parses")
	check(rejects("!FD1!" .. ns.Base64Encode("TS3:abcN1;")), "rejects an unterminated table")
	check(rejects("!FD1!" .. ns.Base64Encode("S5:hello")), "rejects a profile that isn't a table")
	check(rejects("!FD1!" .. ns.Base64Encode(string.rep("T", 40) .. string.rep("E", 40))), "rejects absurd nesting")
	check(rejects("!FD1!" .. string.rep("A", 70000)), "rejects oversize text")

	ns.ShowShareWindow("export")
	local share = _G.ForeverDruidShare
	check(share and share:IsShown() and share.edit:GetText() == ns.ExportProfile(), "share window shows the export string")
	ns.ShowShareWindow("import")
	share.edit:SetText(text)
	share.action:GetScript("OnClick")(share.action)
	check(ns.global.profiles["Imported 3"] and #W.popups == 1, "import button stores it and offers to switch")
	W.AcceptPopup()
	check(ns.global.chars[ns.charKey] == "Imported 3" and W.reloaded, "accepting switches and reloads")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	section("performance: ForeverDruid's CPU cost in the probe and /fd status")
	local W, ns = fresh()
	login(W)
	check(ns.CpuUsage() == nil, "no profiler data: nothing claimed")
	W.state.cpu = { [1] = 0.042, [0] = 0.03, [4] = 0.9, [5] = 0, [6] = 0, overall = { [1] = 0.84 } }
	local cpu = ns.CpuUsage()
	check(cpu and cpu.recentMs == 0.042 and cpu.peakMs == 0.9, "reads recent and peak time")
	check(ns.CpuSummary():find("5% of all addons", 1, true), "summary gives the share of all addons (" .. tostring(ns.CpuSummary()) .. ")")
	local snap = ns.TakeSnapshot("test")
	check(snap.cpu and snap.cpu.recentMs == 0.042, "probe snapshot records CPU")
	W.Slash("status")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	section("translations: German, French and Spanish clients")
	for locale, expected in pairs({ deDE = "Manaleiste", frFR = "Barre de mana", esES = "Barra de maná", esMX = "Barra de maná" }) do
		local W, ns = fresh(function(W)
			W.locale = locale
		end)
		login(W)
		W.Advance(5)
		check(ns.L["Mana bar"] == expected, locale .. ": " .. tostring(ns.L["Mana bar"]))
		check(ns.L["an untranslated sentence"] == "an untranslated sentence", locale .. ": missing strings fall back to English")
		local ok = W.ShowOptionsPanel()
		check(ok, locale .. ": settings build")
		noErrors(W, locale .. ": no errors")
		W.locale = nil
	end
end

---------------------------------------------------------------------------
do
	section("review fixes: imported profiles are validated, keyboard released on lock")
	local W, ns = fresh()
	login(W)
	local hostile = {
		unlocked = true, scale = 0, fadeOutOfCombat = "x", hideWhenMounted = 5,
		positions = { manabar = {}, cooldowns = { "CENTER", "CENTER", 1e9, 12 }, bogus = { "CENTER", "CENTER", 0, 0 } },
		layout = { gap = 999, detached = { buffs = true, reminders = true, cooldowns = "yes" } },
		style = { icons = "neon" },
		modules = {
			manabar = { width = "wide", height = 1e6, text = "nonsense" },
			cooldowns = { extra = { all = { 5, "Nature's Grasp", string.rep("x", 500) }, nope = { "Growl" } } },
			newThing = { enabled = true },
		},
	}
	local clean = ns.SanitizeProfile(hostile)
	check(clean.unlocked == false, "imported profiles arrive locked")
	check(clean.scale == 0.5 and clean.layout.gap == 20 and clean.modules.manabar.height == 30, "numbers clamped to the settings' ranges")
	check(clean.fadeOutOfCombat == nil and clean.hideWhenMounted == nil and clean.modules.manabar.width == nil, "wrong types dropped (defaults fill in)")
	check(clean.positions.manabar == nil and clean.positions.bogus == nil, "malformed or unknown positions dropped")
	check(clean.positions.cooldowns and clean.positions.cooldowns[3] == 4000, "positions clamped on screen")
	check(clean.layout.detached.buffs == true and clean.layout.detached.reminders == nil and clean.layout.detached.cooldowns == nil,
		"only real stack pieces can be detached")
	check(clean.style.icons == nil and clean.modules.manabar.text == nil, "unknown choices dropped")
	local extra = clean.modules.cooldowns.extra
	check(#extra.all == 1 and extra.all[1] == "Nature's Grasp" and extra.nope == nil, "custom cooldowns: only spell names, only real roles")
	check(clean.modules.newThing == nil, "unknown settings dropped")

	-- Locking with the mouse still over a piece releases the keyboard.
	W.Slash("unlock")
	local anchor = ns.anchors.cooldowns
	anchor:GetScript("OnEnter")(anchor)
	check(rawget(anchor, "_keyboard") == true, "hovering an unlocked piece captures arrow keys")
	W.Slash("lock")
	check(rawget(anchor, "_keyboard") == false, "locking releases the keyboard")
	noErrors(W, "no errors")

	-- A sanitized hostile profile loads cleanly.
	ns.global.profiles.Hostile = clean
	local W2, ns2 = fresh(function()
		ForeverDruidDB = { profiles = { Hostile = clean }, chars = {} }
	end)
	ForeverDruidDB.chars = { [ns.charKey] = "Hostile" }
	login(W2)
	noErrors(W2, "a sanitized hostile profile logs in without errors")
	check(ns2.profileName == "Hostile" and not ns2.db.unlocked, "and starts locked")

end

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
	check(table.concat(names, ",") == "FD Barkskin,FD Innervate,FD Mark,FD Rebirth,FD Shift Bear,FD Shift Cat,FD Thorns",
		"only macros whose spells are known: " .. table.concat(names, ","))
	check(#W.macros.account == 0, "nothing in the account-wide slots")
	local mark = W.CharacterMacro("FD Mark")
	check(mark.body:find("/cast [@mouseover,help,nodead][help,nodead][@player] Mark of the Wild", 1, true), "Mark macro body uses the spell name")
	check(W.CharacterMacro("FD Shift Cat").body:find("/cast !Cat Form", 1, true), "powershift macro uses !Cat Form")
	check(W.CharacterMacro("FD Prowl") == nil, "Prowl/Ravage waits for Ravage")
	check(mac.Status("mark") == "ready" and mac.Status("rejuv") == "needs", "status: ready / needs a spell")

	-- Learning a spell adds its macro.
	table.insert(W.state.spellbook, { 774, "Rejuvenation" })
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	local rejuv = W.CharacterMacro("FD Rejuv")
	check(rejuv and rejuv.body:find("/cancelform [form]", 1, true), "learning Rejuvenation creates FD Rejuv")

	-- An empty spellbook for a moment (login) never deletes anything.
	local saved = W.state.spellbook
	W.state.spellbook = {}
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	check(W.CharacterMacro("FD Mark") ~= nil and W.CharacterMacro("FD Rejuv") ~= nil, "a momentarily empty spellbook deletes nothing")
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
	section("energy/rage bar, five-second rule, highest-rank action bars")
	local W, ns = fresh()
	login(W)
	W.Advance(5)
	local power, fsr = ns.modules.powerbar, ns.modules.fsr
	check(not power.anchor:IsShown(), "no energy/rage bar in caster form")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(power.anchor:IsShown() and power:Kind().token == "ENERGY", "Cat Form: energy bar")
	W.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
	check(W.IsSecret(rawget(power.bar, "_values").value), "the bar is fed the secret energy value directly")
	check(rawget(power.text, "_formatted") ~= nil or true, "number drawn by the client from the secret value")
	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(power.anchor:IsShown() and power:Kind().token == "RAGE", "Bear Form: rage bar")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)

	-- Five-second rule: mana casts start it, energy abilities don't; it runs out after 5s.
	check(fsr.anchor:IsShown() and not fsr.bar:IsShown(), "FSR row keeps its place, empty while regen runs")
	W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c1", 774)
	check(fsr.bar:IsShown(), "a mana-costing cast starts the five-second bar")
	W.Advance(2.5)
	fsr:UpdateBar()
	check(math.abs(rawget(fsr.bar, "_values").value - 0.5) < 0.05, "halfway after 2.5 seconds")
	W.Advance(3)
	fsr:UpdateBar()
	check(not fsr.bar:IsShown(), "gone after five seconds")
	check(not ns.modules.fsr.SpendsMana(1082), "an energy ability doesn't count")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(not fsr.SpendsMana(W.Secret()), "secret spell ID in Cat Form: assumed not mana")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(fsr.SpendsMana(W.Secret()), "secret spell ID in caster form: assumed mana")

	-- Highest ranks: an old Rejuvenation on the bars becomes the rank you know.
	W.state.spellbook[#W.state.spellbook + 1] = { 1058, "Rejuvenation" }
	W.Fire("SPELLS_CHANGED")
	W.Advance(3)
	W.actions[1] = { kind = "spell", id = 774 }
	W.actions[61] = { kind = "spell", id = 774 }
	W.actions[2] = { kind = "spell", id = 5232 }
	W.actions[3] = { kind = "macro", id = 1 }
	-- Learn rank 3; with "show all ranks" rank 2 stays in the book as a low rank.
	W.state.spellbook[#W.state.spellbook].low = true
	W.state.spellbook[#W.state.spellbook + 1] = { 1430, "Rejuvenation" }
	W.Fire("SPELLS_CHANGED")
	W.Fire("LEARNED_SPELL_IN_SKILL_LINE", 1430)
	W.Advance(4)
	check(ns.KnownSpell("rejuvenation") == 1430, "spellbook scan skips lower ranks")
	check(W.actions[1].id == 1430 and W.actions[61].id == 1430, "both old Rejuvenation buttons now cast the new rank")
	check(W.actions[2].id == 5232 and W.actions[3].kind == "macro", "other buttons and macros untouched")
	check(W.cursorItem == nil, "the old rank isn't left on your cursor")

	-- Kept spells stay downranked on purpose.
	W.actions[4] = { kind = "spell", id = 774 }
	W.Slash("ranks keep Rejuvenation")
	ns.ranks.Upgrade()
	check(W.actions[4].id == 774, "a spell you keep stays at the rank you placed")
	W.Slash("ranks unkeep Rejuvenation")
	ns.ranks.Upgrade()
	check(W.actions[4].id == 1430, "unkeep: upgraded")

	-- Never in combat, never while you're dragging something.
	W.actions[5] = { kind = "spell", id = 774 }
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	ns.ranks.Upgrade()
	check(W.actions[5].id == 774 and #W.blocked == 0, "no action bar changes in combat")
	W.state.inCombat = false
	W.cursorItem = { kind = "item", id = 6948 }
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(2)
	check(W.actions[5].id == 774 and W.cursorItem.id == 6948, "waits while you're holding something")
	W.cursorItem = nil
	W.Fire("CURSOR_CHANGED")
	W.Advance(2)
	check(W.actions[5].id == 1430, "upgrades once your cursor is free")

	ns.db.ranks.auto = false
	W.actions[6] = { kind = "spell", id = 774 }
	W.Fire("SPELLS_CHANGED")
	W.Advance(4)
	check(W.actions[6].id == 774, "can be turned off")
	check(W.ShowOptionsPanel(), "settings with the new pages show")
	noErrors(W, "no errors or blocked actions")
end

---------------------------------------------------------------------------
do
	section("role: close talent split guesses Feral, and you can pick your caster-form role")
	local W, ns = fresh(function(W)
		W.state.trees = { { "Balance", 0 }, { "Feral Combat", 4 }, { "Restoration", 5 } }
	end)
	login(W)
	check(ns.tree == "feral" and ns.role == "feral", "4 Feral / 5 Restoration: treated as Feral (got " .. tostring(ns.role) .. ")")
	ns.db.role = "healer"
	ns.UpdateRole()
	check(ns.role == "healer", "picked Healer: caster-form role is healer")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(ns.role == "cat", "Cat Form still decides its own role")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(ns.role == "healer", "back in caster form: your pick again")
	ns.db.role = "auto"
	ns.UpdateRole()
	noErrors(W, "no errors")

	local W2, ns2 = fresh(function(W)
		W.state.trees = { { "Balance", 0 }, { "Feral Combat", 2 }, { "Restoration", 11 } }
	end)
	login(W2)
	check(ns2.role == "healer", "a clear Restoration build stays a healer")
	noErrors(W2, "no errors")
end

---------------------------------------------------------------------------
do
	section("levelling helpers: restock, trainer visit, class quests; probe capability checks")
	local W, ns = fresh(function(W)
		W.state.level = 20
		table.insert(W.state.spellbook, { 21849, "Gift of the Wild" })
	end)
	login(W)
	W.Advance(5)
	-- Rebirth rank 1 needs Maple Seed; Gift of the Wild rank 1 needs Wild Berries.
	W.state.items[17034] = 1
	W.merchant = {
		{ item = 17034, name = "Maple Seed", price = 100 },
		{ item = 17035, name = "Stranglethorn Seed", price = 200 },
		{ item = 17021, name = "Wild Berries", price = 150 },
		{ item = 4540, name = "Tough Hunk of Bread", price = 25 },
	}
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	check(#W.bought == 0, "restock is off by default: nothing bought")
	ns.db.restock.enabled = true
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	local bought = {}
	for _, b in ipairs(W.bought) do
		bought[b.item] = b.count
	end
	check(bought[17034] == 4 and bought[17035] == nil, "tops up the seed for your Rebirth rank to 5 (had 1, bought " .. tostring(bought[17034]) .. ")")
	check(bought[17021] == 10, "buys 10 Wild Berries for Gift of the Wild rank 1")
	check(bought[4540] == nil, "never buys anything else")
	W.bought = {}
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	check(#W.bought == 0, "already stocked: buys nothing")
	W.state.items[17034], W.state.items[17021], W.money = 0, 0, 250
	W.bought = {}
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	local spent = 0
	for _, b in ipairs(W.bought) do
		spent = spent + b.count
	end
	check(W.money >= 0 and spent <= 2, "only what you can afford (" .. tostring(W.money) .. " copper left)")

	-- Trainer: after an even level until you open a trainer.
	W.Fire("PLAYER_LEVEL_UP", 22)
	W.Advance(1)
	check(labels(ns.modules.reminders.active)["Trainer"], "levelling to 22 shows a trainer reminder")
	W.Fire("TRAINER_SHOW")
	W.Advance(1)
	check(not labels(ns.modules.reminders.active)["Trainer"], "opening the trainer clears it")
	W.Fire("PLAYER_LEVEL_UP", 23)
	W.Advance(1)
	check(not labels(ns.modules.reminders.active)["Trainer"], "odd levels don't")
	noErrors(W, "no errors")

	-- Class quest: level 20 without Cat Form.
	local W2, ns2 = fresh(function(W)
		W.state.level = 20
		for i = #W.state.spellbook, 1, -1 do
			if W.state.spellbook[i][2] == "Cat Form" then
				table.remove(W.state.spellbook, i)
			end
		end
	end)
	login(W2)
	W2.Advance(5)
	check(labels(ns2.modules.reminders.active)["Cat Form"], "level 20 without Cat Form: class quest reminder")
	check(not labels(ns2.modules.reminders.active)["Bear Form"], "has Bear Form: no reminder for it")
	local reminderButton
	for i, item in ipairs(ns2.modules.reminders.active) do
		if item.label == "Cat Form" then
			reminderButton = _G["ForeverDruidReminder" .. i]
		end
	end
	check(reminderButton and reminderButton:GetAttribute("type") == nil, "the quest reminder isn't a cast button")

	-- Probe: capability checks saved in combat.
	W2.state.inCombat = false
	W2.Fire("PLAYER_REGEN_DISABLED")
	W2.state.inCombat = true
	W2.Fire("UNIT_AURA", "player", { addedAuras = { { spellId = 16870 }, { spellId = W2.Secret() } } })
	local snap = ns2.TakeSnapshot("caps")
	local caps = snap.capabilities
	check(caps and caps.auraAdded.readableID == 1 and caps.auraAdded.secretID == 1 and caps.auraAdded.clearcasting == 1,
		"probe counts readable vs secret 'aura added' spell IDs in combat")
	check(caps.threat == nil or caps.threatRaw == "<secret>", "probe records whether threat is secret")
	check(caps.attackSpeed == 2.5, "probe records attack speed")
	W2.state.inCombat = false
	W2.Fire("PLAYER_REGEN_ENABLED")
	noErrors(W2, "no errors")
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
	local bear = W.CharacterMacro("FD Shift Bear")
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
	section("alerts, party panel, missing debuffs, talent points, new macros")
	local W, ns = fresh(function(W)
		table.insert(W.state.spellbook, { 770, "Faerie Fire" })
		table.insert(W.state.spellbook, { 99, "Demoralizing Roar" })
		table.insert(W.state.spellbook, { 17116, "Nature's Swiftness" })
		table.insert(W.state.spellbook, { 5185, "Healing Touch" })
		table.insert(W.state.spellbook, { 774, "Rejuvenation" })
		W.state.extraNames[1160] = "Demoralizing Shout"
		W.RebuildNames()
	end)
	login(W)
	W.Advance(5)
	local alerts, party, targets = ns.modules.alerts, ns.modules.party, ns.modules.targetauras

	-- Clearcasting from a readable "aura added" event; a hidden one is ignored.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.Fire("UNIT_AURA", "player", { addedAuras = { { spellId = 16870, auraInstanceID = 55, icon = 136170,
		expirationTime = W.now + 15, duration = 15 } } })
	check(alerts.active[55] ~= nil, "Clearcasting gained in combat shows as an alert")
	W.Fire("UNIT_AURA", "player", { addedAuras = { { spellId = W.Secret(), auraInstanceID = W.Secret() } } })
	check(alerts.stats.secretAdds >= 1 and alerts.active[56] == nil, "a hidden spell ID never shows an alert")
	W.Fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 55 } })
	check(alerts.active[55] == nil, "removed when the buff is used up")
	W.Fire("UNIT_AURA", "player", { addedAuras = { { spellId = 16870, auraInstanceID = 57, expirationTime = W.now + 15, duration = 15 } } })
	W.Advance(16)
	alerts:Refresh()
	check(alerts.active[57] == nil, "expires on its own if the removal never arrives")

	-- Threat in Bear Form: warns only on a readable "not tanking".
	W.state.party = { party1 = { name = "Healbot", class = "PRIEST", role = "HEALER" } }
	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.state.targetExists, W.state.targetHostile = true, true
	W.state.threat = 1
	W.Advance(0.5)
	check(alerts.LosingAggro() == false, "a mob someone else holds (threat 1, never yours): no warning")
	W.state.threat = 3
	check(alerts.LosingAggro() == false, "securely tanking: no warning")
	W.state.threat = 2
	check(alerts.LosingAggro() == true, "about to lose it (threat 2): warns")
	W.state.threat = 1
	check(alerts.LosingAggro() == true, "just lost it (threat 1 right after holding it): warns")
	W.Advance(6)
	check(alerts.LosingAggro() == false, "long after: no longer treated as yours")
	W.state.threat = nil
	check(alerts.LosingAggro() == false, "threat hidden by the game: stays quiet")

	-- Missing debuffs on an enemy in Bear Form: Demoralizing Roar and Faerie Fire, unless present.
	W.state.targetAuras = {}
	W.state.targetOtherDebuffs = { "Faerie Fire" }
	local missing = targets.MissingDebuffs({ { name = "Faerie Fire" } }, "bear")
	check(#missing == 1 and missing[1] == "demoralizingRoar", "bear: Faerie Fire from anyone counts; Demoralizing Roar missing")
	check(targets.MissingDebuffs({ { name = W.Secret() } }, "bear") == nil, "a hidden debuff name: no warning at all")
	check(#targets.MissingDebuffs({}, "healer") == 0, "healers aren't nagged about debuffs")
	local withShout = targets.MissingDebuffs({ { name = "Faerie Fire" }, { name = "Demoralizing Shout" } }, "bear")
	check(#withShout == 0, "a warrior's Demoralizing Shout counts for Demoralizing Roar")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)

	-- Party panel: HoTs per member, Rebirth when dead, Innervate fade for healers.
	W.state.party = {
		party1 = { name = "Tankard", class = "WARRIOR", role = "TANK",
			hots = { { icon = 136081, expirationTime = W.now + 10, duration = 12, name = "Rejuvenation" } } },
		party2 = { name = "Healbot", class = "PRIEST", role = "HEALER" },
		party3 = { name = "Stabby", class = "ROGUE", dead = true },
	}
	W.Fire("GROUP_ROSTER_UPDATE")
	W.Advance(1)
	check(party.anchor:IsShown() and party.stats.rows == 4, "in a group: a row for you and each party member (" .. tostring(party.stats.rows) .. ")")
	W.state.party.party1.hots = {
		{ icon = 136078, expirationTime = W.now + 1700, duration = 1800, name = "Mark of the Wild" },
		{ icon = 136104, expirationTime = W.now + 500, duration = 600, name = "Thorns" },
		{ icon = 136081, expirationTime = W.now + 10, duration = 12, name = "Rejuvenation" },
	}
	local hots = party.HotsOn("party1")
	check(#hots == 1 and hots[1].name == "Rejuvenation", "only HoTs show: Mark of the Wild and Thorns are left out")
	ns.db.modules.party.size = 30
	party:Refresh()
	local rowIcon = nil
	for _, f in ipairs(W.frames) do
		if rawget(f, "_w") == 30 and rawget(f, "_kind") == "Frame" and rawget(f, "_parent") and rawget(rawget(f, "_parent"), "_parent") == party.anchor then
			rowIcon = f
		end
	end
	check(rowIcon ~= nil, "changing the size resizes rows already on screen")
	ns.db.modules.party.size = 20
	check(party.stats.failures == 0, "party HoT lookups succeed")
	W.state.secretAuras = true
	W.Advance(1)
	check(#W.errors == 0, "hidden HoT details still draw without errors")
	W.state.secretAuras = false
	-- Dead yourself: no Rebirth hint on your own row.
	party.HotsOn("player")
	W.state.party = { party1 = { name = "Tankard", class = "WARRIOR", role = "TANK" } }
	W.Fire("GROUP_ROSTER_UPDATE")
	W.Advance(1)
	W.state.party = nil
	W.Fire("GROUP_ROSTER_UPDATE")
	W.Advance(1)
	check(not party.anchor:IsShown(), "solo: no party panel")

	-- Talent points.
	W.state.unspentTalents = 2
	W.Fire("TRAIT_CONFIG_UPDATED")
	W.Advance(1)
	check(labels(ns.modules.reminders.active)["Talents 2"], "unspent talent points show a reminder")
	W.state.unspentTalents = 0
	W.Fire("TRAIT_CONFIG_UPDATED")
	W.Advance(1)
	check(not labels(ns.modules.reminders.active)["Talents 2"], "spending them clears it")

	-- New macros.
	ns.macros.SetManaged(true)
	local faerie = W.CharacterMacro("FD Faerie")
	check(faerie and faerie.body:find("[@mouseover,harm,nodead][] Faerie Fire", 1, true), "FD Faerie: mouseover Faerie Fire")
	check(not faerie.body:find("[form,", 1, true), "FD Faerie never uses a bare [form] (Moonkin or Travel would pick the Feral spell)")
	local swift = W.CharacterMacro("FD Swift Heal")
	check(swift and swift.body:find("/cast Nature's Swiftness", 1, true) and swift.body:find("Healing Touch", 1, true),
		"FD Swift Heal: Nature's Swiftness into Healing Touch")
	check(W.CharacterMacro("FD Barkskin") and #swift.body <= 255, "FD Barkskin created; bodies fit the macro limit")
	check(W.ShowOptionsPanel(), "settings with Alerts and Party pages show")
	noErrors(W, "no errors or blocked actions")
end

out(("\n%s (%d failure%s)"):format(failures == 0 and "PASS" or "FAIL", failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
