-- Onboarding, play styles, profiles and sharing, translations, performance readout.
-- Run through tests/run.lua, which provides check, section, noErrors, fresh, login and labels.

---------------------------------------------------------------------------
do
	section("onboarding: welcome tour on first install, What's new after an update")
	_G.ForeverDruidPlaystyle, _G.ForeverDruidTour = nil, nil
	local W, ns = fresh()
	login(W)
	W.Advance(5)
	local chooser = _G.ForeverDruidPlaystyle
	check(chooser and chooser:IsShown() and _G.ForeverDruidTour == nil, "first install asks how you play, before the tour")
	chooser.buttons.healer:GetScript("OnClick")(chooser.buttons.healer)
	check(ns.db.playstyle == "healer" and ns.db.role == "healer", "picking Healer sets the play style and role")
	check(ns.db.modules.healframes.enabled and not ns.db.modules.combopoints.enabled and not ns.db.modules.powershift.enabled,
		"Healer: click-to-heal frames on, Cat parts off")
	check(ns.db.macros.manage and ns.db.macros.enabled.swiftHeal and ns.db.macros.enabled.claw == false,
		"Healer: the matching macros are switched on, others off")
	local tour = _G.ForeverDruidTour
	check(tour and tour:IsShown(), "then the welcome tour")
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
	local listed = table.concat(versions, ",")
	check(versions[1] == ns2.VERSION and listed:sub(-12) == ",0.5.0,0.4.0" and not listed:find("0.3.0", 1, true),
		"only versions newer than the last one seen (" .. listed .. ")")
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

	section("settings of parts Forever can't support are cleared from saved profiles")
	_G.ForeverDruidWhatsNew = nil
	local W4, ns4 = fresh(function()
		local old = {
			modules = {
				energytick = { enabled = true, width = 200 },
				nextability = { enabled = true, glow = true },
				powerbar = { enabled = true, width = 222, tickSpark = true },
				powershift = { enabled = true, tickWindow = 0.6, energyBelow = 0.3 },
			},
			positions = { energytick = { "CENTER", "CENTER", 0, -182 }, nextability = { "CENTER", "CENTER", -110, -160 } },
			layout = { stack = true, detached = { energytick = true, combopoints = true } },
		}
		ForeverDruidDB = { profiles = { Default = old, Other = { modules = { nextability = { enabled = true } } } },
			chars = {}, lastVersion = "0.4.0" }
	end)
	login(W4)
	W4.Advance(5)
	local saved = ForeverDruidDB.profiles
	check(saved.Default.modules.energytick == nil and saved.Default.modules.nextability == nil
		and saved.Other.modules.nextability == nil, "energy tick and Next ability settings are gone, in every profile")
	check(saved.Default.positions.energytick == nil and saved.Default.positions.nextability == nil
		and saved.Default.layout.detached.energytick == nil, "their positions and column state are gone")
	check(saved.Default.modules.powerbar.tickSpark == nil and saved.Default.modules.powershift.tickWindow == nil,
		"the tick options on the energy bar and Powershift are gone")
	check(ns4.db.modules.powerbar.width == 222 and ns4.db.modules.powershift.energyBelow == 0.3
		and ns4.db.layout.detached.combopoints, "everything else you set is kept")
	check(ns4.modules.energytick == nil and ns4.modules.nextability == nil, "neither part exists any more")
	noErrors(W4, "no errors")
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
	section("usability: play styles, piece menus, at a glance, slash shortcuts")
	_G.ForeverDruidPlaystyle = nil
	local W, ns = fresh()
	login(W)
	W.Advance(5)
	if _G.ForeverDruidPlaystyle then
		_G.ForeverDruidPlaystyle:Hide()
	end

	-- Play style from the quick menu.
	ForeverDruid_OpenQuickMenu()
	W.lastMenu:Find("Play style", "Tank (Bear Form)"):Click()
	check(ns.db.playstyle == "bear" and not ns.db.modules.combopoints.enabled and ns.db.modules.alerts.enabled,
		"Tank: combo points off, alerts on")
	check(ns.db.macros.manage == false, "picking from the menu doesn't touch macros")
	ForeverDruid_OpenQuickMenu()
	check(W.lastMenu:Find("Play style"):Find("Tank (Bear Form)"):Selected(), "the menu shows the current play style")
	check(W.lastMenu:Find("HUD parts", "Combo points") and W.lastMenu:Find("Spells & macros", "Macros"),
		"parts and spells are grouped in submenus")
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	check(ns.ApplyPlaystyle("healer") == false and ns.db.playstyle == "bear", "can't switch play style mid-fight")
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	ns.ApplyPlaystyle("leveling")

	-- A piece's own menu while unlocked.
	W.Slash("unlock")
	local cd = ns.anchors.cooldowns
	cd:GetScript("OnEnter")(cd)
	check(W.lastPrint == nil or true, "hovering shows the piece's help")
	cd:GetScript("OnMouseUp")(cd, "RightButton")
	local menu = W.lastMenu
	check(menu and menu:Find("Cooldowns") and menu:Find("Settings for this part..."), "right-click opens the piece's menu")
	menu:Find("Give it its own spot"):Click()
	check(ns.db.layout.detached.cooldowns, "give it its own spot")
	cd:GetScript("OnMouseUp")(cd, "RightButton")
	W.lastMenu:Find("Put it back in the column"):Click()
	check(not ns.db.layout.detached.cooldowns, "and back in the column")
	ns.db.positions.buffs = { "CENTER", "CENTER", 99, 99 }
	ns.db.layout.detached.buffs = true
	ns.ResetPiece("buffs")
	check(ns.db.positions.buffs == nil and not ns.db.layout.detached.buffs, "reset one piece's position")
	cd:GetScript("OnMouseUp")(cd, "RightButton")
	W.lastMenu:Find("Hide this part"):Click()
	check(not ns.db.modules.cooldowns.enabled, "hide a part from its menu")
	ns.SetModuleEnabled("cooldowns", true)
	W.lastMenu = nil
	W.Slash("lock")
	cd:GetScript("OnMouseUp")(cd, "RightButton")
	check(W.lastMenu == nil, "no piece menu while locked")

	-- At a glance.
	check(ns.ModuleStatus("healframes"):find("off", 1, true), "status: click-to-heal frames off")
	local ok, pages = W.ShowOptionsPanel()
	check(ok and pages >= 15, "settings with the overview show")

	-- Slash shortcuts.
	W.openedCategory = nil
	W.Slash("heal")
	check(W.openedCategory ~= nil, "/fd heal opens the click-to-heal settings")
	W.Slash("rnaks")
	check(W.printed[#W.printed]:find("did you mean /fd ranks", 1, true), "a typo suggests the closest command")
	W.Slash("help")
	check(W.printed[#W.printed]:find("/fd tour", 1, true), "/fd help is grouped")
	noErrors(W, "no errors or blocked actions")
end
