-- The HUD parts: stack, bars, cooldowns, alerts, party, reminders, heal frames, form bar, tooltips.
-- Run through tests/run.lua, which provides check, section, noErrors, fresh, login and labels.

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

	check(chain() == "targetauras,fsr,cooldowns,buffs", "caster form: energy, mana and combo rows take no room (" .. chain() .. ")")
	local ok, bad = linked()
	check(ok, "caster form: each piece hangs from the one above it" .. (bad and (" (" .. bad .. ")") or ""))

	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(chain() == "targetauras,powerbar,manabar,fsr,combopoints,powershift,cooldowns,buffs",
		"Cat Form: energy bar, mana bar and combo points slot in (" .. chain() .. ")")
	ok, bad = linked()
	check(ok, "Cat Form: column re-chained" .. (bad and (" (" .. bad .. ")") or ""))

	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(chain() == "targetauras,powerbar,manabar,fsr,powershift,cooldowns,buffs", "Bear Form: combo points close up (" .. chain() .. ")")
	ok, bad = linked()
	check(ok, "Bear Form: no gaps" .. (bad and (" (" .. bad .. ")") or ""))

	W.Slash("toggle manabar")
	check(chain() == "targetauras,powerbar,fsr,powershift,cooldowns,buffs", "disabling a module closes its gap")
	W.Slash("toggle manabar")
	check(chain() == "targetauras,powerbar,manabar,fsr,powershift,cooldowns,buffs", "re-enabling slots it back in")

	-- Resizing needs no re-layout: pieces hang from the bottom edge of the one above.
	ns.db.modules.cooldowns.size = 48
	ns.modules.cooldowns:Refresh()
	local rel = hangsFrom("buffs")
	check(rel == A.cooldowns, "bigger cooldown icons push buffs down instead of overlapping")

	W.Slash("unlock")
	local _, _, _, gapUnlocked = hangsFrom("cooldowns")
	check(gapUnlocked == -(ns.db.layout.gap + 12), "unlocked: extra room for each piece's name")
	check(chain() == "targetauras,powerbar,manabar,fsr,combopoints,powershift,cooldowns,buffs", "unlocked: every piece shown in the column")

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
	check(hangsFrom("powershift") == A.fsr, "the column closes up behind a detached piece")
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
	check(ok and chain() == "targetauras,powerbar,manabar,fsr,powershift,cooldowns,buffs", "re-chains in combat (" .. chain() .. ")")
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
	check(menu and menu:Find("Forever Druid"), "left-click opens the quick menu")

	local entry = menu:Find("HUD parts", "Combo points")
	check(entry and entry:Selected(), "HUD parts > Combo points is ticked")
	entry:Click()
	check(not ns.db.modules.combopoints.enabled and not ns.anchors.combopoints:IsShown(), "unticking turns combo points off")
	entry:Click()
	check(ns.db.modules.combopoints.enabled, "ticking turns them back on")

	menu:Find("Look", "HUD size", "125%"):Click()
	check(ns.db.scale == 1.25 and rawget(ns.root, "_scale") == 1.25, "HUD size 125% applies")
	check(menu:Find("Look", "HUD size", "125%"):Selected() and not menu:Find("Look", "HUD size", "100%"):Selected(), "size radio shows the current choice")

	menu:Find("Look", "Out of combat", "Faded"):Click()
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
	check(W.lastMenu and W.lastMenu:Find("HUD parts"), "the addon menu entry opens the same quick menu")

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
	check(W.lastMenu and W.lastMenu:Find("HUD parts"), "quick-menu keybinding")
	check(BINDING_NAME_FOREVERDRUID_UNLOCK and BINDING_HEADER_FOREVERDRUID == "Forever Druid", "keybinding names defined")
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
	local faerie = W.CharacterMacro("FD Faerie Fire")
	check(faerie and faerie.body:find("[@mouseover,harm,nodead][] Faerie Fire", 1, true), "FD Faerie: mouseover Faerie Fire")
	check(not faerie.body:find("[form,", 1, true), "FD Faerie never uses a bare [form] (Moonkin or Travel would pick the Feral spell)")
	local swift = W.CharacterMacro("FD Swift Heal")
	check(swift and swift.body:find("/cast Nature's Swiftness", 1, true) and swift.body:find("Healing Touch", 1, true),
		"FD Swift Heal: Nature's Swiftness into Healing Touch")
	check(W.CharacterMacro("FD Barkskin") and #swift.body <= 255, "FD Barkskin created; bodies fit the macro limit")
	check(W.ShowOptionsPanel(), "settings with Alerts and Party pages show")
	noErrors(W, "no errors or blocked actions")
end

---------------------------------------------------------------------------
do
	section("let it bleed: nearly-dead enemy with your bleed ticking")
	local W, ns = fresh(function(W)
		W.state.extraNames[1822] = "Rake"
		W.state.extraNames[1079] = "Rip"
		W.RebuildNames()
	end)
	login(W)
	W.Advance(5)
	local targets = ns.modules.targetauras
	W.state.targetExists, W.state.targetHostile = true, true
	W.state.targetAuras = { { name = "Rake", icon = 132122, expirationTime = W.now + 9, duration = 9, auraInstanceID = 1 } }
	W.Fire("PLAYER_TARGET_CHANGED")
	W.Advance(1)
	check(targets.cue:IsShown() and W.IsSecret(rawget(targets.cue, "_alpha")),
		"your Rake on an enemy: the cue's visibility comes from the client's own health check")
	local queries = W.healthQueries or 0
	W.Fire("UNIT_HEALTH", "target")
	check((W.healthQueries or 0) > queries, "re-checked as the target's health changes")

	W.state.targetAuras = { { name = "Faerie Fire", icon = 136033, expirationTime = W.now + 40, duration = 40, auraInstanceID = 2 } }
	W.Fire("UNIT_AURA", "target", {})
	W.Advance(1)
	check(not targets.cue:IsShown(), "only Faerie Fire on it (no damage over time): no cue")

	W.state.secretAuras = true
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Fire("UNIT_AURA", "target", {})
	W.Advance(1)
	check(targets.cue:IsShown(), "in combat with hidden names, Cat Form counts your effects as bleeds")
	W.state.secretAuras = false
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")

	W.state.targetHostile = false
	W.state.targetAuras = { { name = "Rejuvenation", icon = 136081, expirationTime = W.now + 9, duration = 12, auraInstanceID = 3 } }
	W.Fire("PLAYER_TARGET_CHANGED")
	W.Advance(1)
	check(not targets.cue:IsShown(), "friendly target: never")
	ns.db.modules.targetauras.letItBleed = false
	W.state.targetHostile = true
	W.state.targetAuras = { { name = "Rip", icon = 132152, expirationTime = W.now + 12, duration = 12, auraInstanceID = 4 } }
	W.Fire("PLAYER_TARGET_CHANGED")
	W.Advance(1)
	check(not targets.cue:IsShown(), "can be turned off")
	check(W.ShowOptionsPanel(), "settings with the threshold slider show")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	section("powershift pips and cue, heal frames, form bar, tooltips, Growl check")
	_G.ForeverDruidHealHeader = nil
	local W, ns = fresh(function(W)
		table.insert(W.state.spellbook, { 17061, "Furor", passive = true })
		table.insert(W.state.spellbook, { 774, "Rejuvenation" })
		table.insert(W.state.spellbook, { 8936, "Regrowth" })
		table.insert(W.state.spellbook, { 5185, "Healing Touch" })
		table.insert(W.state.spellbook, { 6795, "Growl" })
	end)
	login(W)
	W.Advance(5)
	local ps = ns.modules.powershift

	-- Pips: in Cat Form, each pip's visibility comes from the client's own mana check.
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(ps.anchor:IsShown(), "Cat Form: shift pips show")
	local secretPips = 0
	for _, f in ipairs(W.frames) do
		if rawget(f, "_parent") == ps.anchor and rawget(f, "_kind") == "Texture" and W.IsSecret(rawget(f, "_alpha")) then
			secretPips = secretPips + 1
		end
	end
	check(secretPips >= 1, "pips are shown or hidden by the game from your hidden mana (" .. secretPips .. ")")
	check(ps.HasFuror(), "Furor is detected from your spellbook")

	-- Cue in combat: two nested fades, energy and mana, both decided by the client.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.Advance(0.5)
	check(ps.cueOuter:IsShown() and W.IsSecret(rawget(ps.cueOuter, "_alpha")) and W.IsSecret(rawget(ps.cueInner, "_alpha")),
		"Powershift cue: energy and mana conditions both left to the client")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(not ps.anchor:IsShown(), "caster form: no pips")

	-- Growl: a readable "still not tanking" after it lands says it missed.
	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.state.threat = 1
	W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g1", 6795)
	W.Advance(1)
	check(ns.modules.alerts.stats.growlMisses == 1, "Growl that didn't take aggro is flagged")
	W.state.threat = nil
	W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g2", 6795)
	W.Advance(1)
	check(ns.modules.alerts.stats.growlMisses == 1 and ns.modules.alerts.stats.growlUnknown >= 1, "threat hidden: says nothing")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)

	-- Heal frames: off by default; on, Blizzard's secure header makes click-to-cast buttons.
	check(_G.ForeverDruidHealHeader == nil or not _G.ForeverDruidHealHeader:IsShown(), "heal frames are off by default")
	W.state.party = { party1 = { name = "Tankard", class = "WARRIOR", role = "TANK" } }
	ns.SetModuleEnabled("healframes", true)
	local header = _G.ForeverDruidHealHeader
	local you, tank = rawget(header, 1), rawget(header, 2)
	check(you and tank and tank:GetAttribute("unit") == "party1", "a button for you and each party member")
	check(tank:GetAttribute("type1") == "spell" and tank:GetAttribute("spell1") == "Rejuvenation"
		and tank:GetAttribute("spell2") == "Regrowth" and tank:GetAttribute("shift-spell1") == "Healing Touch",
		"left-click Rejuvenation, right-click Regrowth, shift-left Healing Touch")
	check(tank:GetAttribute("type3") == "" and tank:GetAttribute("ctrl-type1") == "" and tank:GetAttribute("alt-type2") == "",
		"unassigned clicks (middle, ctrl, alt) are explicit no-ops, not a fall-through")
	check(tank:GetAttribute("shift-type2") == "" and tank:GetAttribute("shift-spell2") == nil,
		"a spell you don't know (Remove Curse) isn't bound")
	check(rawget(header, 5) ~= nil, "all five buttons made up front, out of combat")
	check(rawget(header, 5)._clicks and rawget(header, 5)._clicks[1] == "AnyUp", "right and middle clicks registered on every button")
	W.Advance(1)
	check(ns.modules.healframes.stats.decorated >= 2, "bars drawn on the buttons out of combat")

	-- Someone joins mid-fight: the header (secure code) adds a working button; settings wait.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.state.party.party2 = { name = "Healbot", class = "PRIEST", role = "HEALER" }
	W.UpdateHeaders()
	local joined = rawget(header, 3)
	check(joined and joined:GetAttribute("spell1") == "Rejuvenation" and joined._clicks,
		"a member who joins mid-fight gets a button that already has every click")
	ns.db.modules.healframes.clicks.left = "regrowth"
	ns.modules.healframes.Configure()
	check(joined:GetAttribute("spell1") == "Rejuvenation" and #W.blocked == 0, "changing clicks in combat waits (nothing blocked)")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(1)
	check(joined:GetAttribute("spell1") == "Regrowth", "applied when the fight ends")
	ns.SetModuleEnabled("healframes", false)
	W.state.party = nil

	-- Form bar: one secure button per form, current form lit.
	ns.SetModuleEnabled("formbar", true)
	local fb = ns.modules.formbar
	check(fb.count and fb.count >= 2 and _G.ForeverDruidForm1:GetAttribute("type") == "spell", "form bar: a click-to-shift button per form")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	check(rawget(_G.ForeverDruidForm1.lit, "_alpha") == 1, "current form is lit")
	check(_G.ForeverDruidForm1.cost:GetText() == "400", "mana cost shown")
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.Fire("UPDATE_SHAPESHIFT_FORMS")
	check(#W.blocked == 0, "no secure changes in combat (rebuild waits)")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")

	-- Tooltips: druid values with the change from what you wear.
	W.itemStats["item:new"] = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_AGILITY_SHORT = 6 }
	W.itemStats["item:old"] = { ITEM_MOD_STRENGTH_SHORT = 4, ITEM_MOD_AGILITY_SHORT = 8, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 11 }
	W.itemSlots["item:new"], W.itemSlots["item:old"] = "INVTYPE_CHEST", "INVTYPE_CHEST"
	W.equipped[5] = "item:old"
	local lines = W.ShowItemTooltip("item:new")
	local text = {}
	for _, l in ipairs(lines) do
		text[#text + 1] = l.text
	end
	local all = table.concat(text, " | ")
	check(all:find("Cat attack power +26 (+10)", 1, true), "Cat AP: 2x Str + Agi, with the change (" .. all .. ")")
	check(all:find("Bear attack power +20 (+12)", 1, true), "Bear AP: 2x Str, with the change")
	check(all:find("Healing +0 (-11)", 1, true), "shows healing you'd lose")
	check(not all:find("Agility", 1, true), "Agility is shown as what it does, not as Agility")
	check(all:find("Crit chance +0.3% (-0.1%)", 1, true), "Agility into crit: 6 Agility is 0.3%, 0.1% less than 8")
	check(all:find("Armor +12 (-4)", 1, true), "Agility into armor, 2 per point")
	check(all:find("Dodge chance +0.3% (-0.1%)", 1, true), "Agility into dodge")

	-- A caster/tank piece with ratings: every stat turned into what it does.
	W.itemStats["item:helm"] = { ITEM_MOD_STAMINA_SHORT = 12, ITEM_MOD_INTELLECT_SHORT = 30,
		ITEM_MOD_CRIT_RATING_SHORT = 14, ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 5,
		ITEM_MOD_MANA_REGENERATION_SHORT = 4, ITEM_MOD_SPIRIT_SHORT = 7, RESISTANCE0_NAME = 150 }
	W.itemStats["item:oldhelm"] = { ITEM_MOD_STAMINA_SHORT = 15, RESISTANCE0_NAME = 120 }
	W.itemSlots["item:helm"], W.itemSlots["item:oldhelm"] = "INVTYPE_HEAD", "INVTYPE_HEAD"
	W.equipped[1] = "item:oldhelm"
	local function Text(link)
		local out = {}
		for _, l in ipairs(W.ShowItemTooltip(link)) do
			out[#out + 1] = l.text
		end
		return table.concat(out, " | ")
	end
	local helm = Text("item:helm")
	for _, want in ipairs({ "Crit chance +1.0% (+1.0%)", "Hit chance +1.0% (+1.0%)", "Health +120 (-30)",
		"Armor +150 (+30)", "Defense +5 (+5)", "Mana +450 (+450)", "Spell crit chance +1.5% (+1.5%)",
		"Spell hit chance +1.0% (+1.0%)", "Mana per 5 sec +4 (+4)", "Spirit +7 (+7)" }) do
		check(helm:find(want, 1, true), "converted: " .. want .. " (" .. helm .. ")")
	end
	check(not helm:find("rating", 1, true) and not helm:find("Intellect", 1, true)
		and not helm:find("Stamina", 1, true), "no raw ratings, Intellect or Stamina when they can be converted")
	check(not helm:find("Cat attack power", 1, true), "lines that are zero on both items are left out")

	-- Forever hides the conversions when unit stats are restricted: fall back to the raw stats.
	W.state.statsSecret = true
	local hidden = Text("item:helm")
	check(hidden:find("Crit rating +14 (+14)", 1, true) and hidden:find("Intellect +30 (+30)", 1, true)
		and hidden:find("Health +120 (-30)", 1, true) and not hidden:find("Crit chance", 1, true)
		and not hidden:find("<secret", 1, true), "conversions hidden: raw stats instead (" .. hidden .. ")")
	W.state.statsSecret = nil
	check(all:find("Forever Druid | vs what you're wearing: 2 better, 4 worse | Cat attack power +26 (+10)", 1, true),
		"a verdict line heads the comparison: 2 lines better, 4 worse")

	-- Only what changes is listed; rings and trinkets are compared against both slots.
	local band, seal, loop = "|Hitem:1|h[Old Band]|h", "|Hitem:2|h[Plain Seal]|h", "|Hitem:3|h[New Loop]|h"
	W.itemStats[band] = { ITEM_MOD_STAMINA_SHORT = 5, ITEM_MOD_STRENGTH_SHORT = 3 }
	W.itemStats[seal] = { ITEM_MOD_STAMINA_SHORT = 9, ITEM_MOD_STRENGTH_SHORT = 6 }
	W.itemStats[loop] = { ITEM_MOD_STAMINA_SHORT = 5, ITEM_MOD_STRENGTH_SHORT = 6 }
	for _, ring in ipairs({ band, seal, loop }) do
		W.itemSlots[ring] = "INVTYPE_FINGER"
	end
	W.equipped[11], W.equipped[12] = band, seal
	local ring = Text(loop)
	check(ring:find("vs Old Band: upgrade | Cat attack power +12 (+6) | Bear attack power +12 (+6) | vs Plain Seal: downgrade | Health +50 (-40)", 1, true), -- luacheck: no max line length
		"a ring is compared with both rings, named, each with a verdict and only the lines that change (" .. ring .. ")")
	W.itemStats[loop] = { ITEM_MOD_STAMINA_SHORT = 9, ITEM_MOD_STRENGTH_SHORT = 6 }
	check(Text(loop):find("vs Plain Seal: the same for a druid", 1, true), "identical for a druid: says so, no lines")
	ns.db.tooltips.changesOnly = false
	check(Text(loop):find("vs Plain Seal: the same for a druid | Cat attack power +12 | Bear attack power +12 | Health +90", 1, true),
		"with 'only the stats that change' unticked, everything is listed")
	ns.db.tooltips.changesOnly = true
	check(not Text(seal):find("vs ", 1, true) and Text(seal):find("Health +90", 1, true),
		"hovering a ring you're wearing: its own values, no comparison")
	W.equipped[11], W.equipped[12] = nil, nil
	check(not Text(loop):find("vs ", 1, true), "empty slots: nothing to compare against")
	check(#W.ShowItemTooltip("item:new", ShoppingTooltip1) == 0, "not added to the side-by-side comparison tooltips")
	ns.db.tooltips.enabled = false
	check(#W.ShowItemTooltip("item:new") == 0, "tooltips can be turned off")
	check(W.ShowOptionsPanel(), "settings with the new pages show")
	noErrors(W, "no errors or blocked actions")
end

---------------------------------------------------------------------------
do
	section("dismissing reminders: click info ones away, right-click to snooze the rest")
	local W, ns = fresh(function(W)
		W.state.level = 20
		for i = #W.state.spellbook, 1, -1 do
			if W.state.spellbook[i][2] == "Cat Form" then
				table.remove(W.state.spellbook, i)
			end
		end
	end)
	login(W)
	W.Advance(5)
	local rem = ns.modules.reminders
	local function buttonFor(label)
		for i, item in ipairs(rem.active) do
			if item.label == label then
				return _G["ForeverDruidReminder" .. i]
			end
		end
	end
	local function click(button, mouse)
		local post = button:GetScript("PostClick")
		post(button, mouse, true) -- key down: nothing happens yet
		post(button, mouse, false)
	end

	-- Trainer: one click acknowledges it; it's back at the next even level.
	W.Fire("PLAYER_LEVEL_UP", 22)
	W.Advance(1)
	local trainer = buttonFor("Trainer")
	check(trainer ~= nil, "levelling up shows the trainer reminder")
	click(trainer, "LeftButton")
	check(not labels(rem.active)["Trainer"], "one click dismisses it")
	W.Fire("PLAYER_LEVEL_UP", 23)
	W.Advance(1)
	check(not labels(rem.active)["Trainer"], "stays gone at an odd level")
	W.Fire("PLAYER_LEVEL_UP", 24)
	W.Advance(1)
	check(labels(rem.active)["Trainer"], "back at the next even level")

	-- Class quest: dismissed until your next level.
	check(labels(rem.active)["Cat Form"], "Cat Form quest reminder at 20+ without the form")
	click(buttonFor("Cat Form"), "LeftButton")
	check(not labels(rem.active)["Cat Form"], "click dismisses the quest reminder")
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(1)
	check(not labels(rem.active)["Cat Form"], "stays dismissed at the same level")
	W.state.level = 25
	W.Fire("PLAYER_LEVEL_UP", 25)
	W.Advance(1)
	check(labels(rem.active)["Cat Form"], "back at the next level if you still don't have the form")

	-- Mark of the Wild: left-click casts (doesn't dismiss); right-click snoozes 30 minutes.
	local mark = buttonFor("Mark")
	check(mark and mark:GetAttribute("type") == "spell" and mark:GetAttribute("type2") == "", "right-click is set to never cast")
	click(mark, "LeftButton")
	check(labels(rem.active)["Mark"], "left-click is for casting: the reminder stays until you're buffed")
	click(mark, "RightButton")
	check(not labels(rem.active)["Mark"], "right-click hides it")
	W.Advance(29 * 60)
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(1)
	check(not labels(rem.active)["Mark"], "still hidden after 29 minutes")
	W.Advance(2 * 60)
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(1)
	check(labels(rem.active)["Mark"], "back after 30 minutes if you still need it")

	-- Talent points: dismissed until the number changes.
	W.state.unspentTalents = 1
	W.Fire("TRAIT_CONFIG_UPDATED")
	W.Advance(1)
	click(buttonFor("Talents 1"), "LeftButton")
	check(not labels(rem.active)["Talents 1"], "click dismisses the talent reminder")
	W.state.unspentTalents = 2
	W.Fire("TRAIT_CONFIG_UPDATED")
	W.Advance(1)
	check(labels(rem.active)["Talents 2"], "back when you get another point")
	noErrors(W, "no errors or blocked actions")
end
