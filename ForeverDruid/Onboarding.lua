-- First-login welcome, "What's new" after an update, and the confirmation popup other files use.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Release notes: written for players, newest first. Shown once after updating.
---------------------------------------------------------------------------

ns.RELEASE_NOTES = {
	{ version = "0.8.0", notes = {
		"24 new macros, off until you tick them on the Macros page (or pick a play style): Growl, Bash and Feral Charge from any form, Maul woven into Lacerate, Primal Bite and Swipe, Berserk with Tiger's Fury, Dash, a Pounce opener, one-button travel forms, Moonkin Form, Hurricane at your cursor, mouseover Moonfire, Insect Swarm, Soothe Animal and Wild Growth, Heal or Wrath, poison and curse cleansing, a Bear Form survival button, Healthstone then potion, Spirit-weapon Innervate, a Bear weapon swap, both trinkets and next target. The potion and weapon macros pick the best one from your bags.", -- luacheck: no max line length
		"Better macros you already have: Shift for Swiftmend on Rejuvenation and Gift of the Wild on Mark, Revive out of combat on Rebirth, Shift for your focus on Roots and Hibernate, Prowl gets you off your mount, and the Ravage opener carries on with Shred. Barkskin no longer drops your form, and buffs and heals no longer drop Moonkin Form or Tree of Life where Forever still lets you cast them.", -- luacheck: no max line length
		"Macros are named after their spell where it fits: FD Rejuv is now FD Rejuvenation, FD Heal Touch is FD Healing Touch, FD Shift Cat and FD Shift Bear are FD Cat Form and FD Bear Form, FD Faerie is FD Faerie Fire and FD Opener is FD Ravage Opener. They keep their place on your action bars.", -- luacheck: no max line length
	} },
	{ version = "0.7.0", notes = {
		"Item tooltips now show everything an item does for you, not just attack power: crit, hit, dodge and spell crit chance, health, armor, mana, healing and more, each with the change from what you're wearing.", -- luacheck: no max line length
		"Each comparison opens with a verdict, such as upgrade or 2 better, 4 worse, and lists only the stats that change. Rings and trinkets are compared with both of yours.", -- luacheck: no max line length
	} },
	{ version = "0.6.0", notes = {
		"Aggro radius on enemy nameplates: a dot and the estimated radius (22y) turn red when you're inside it, orange when you might be, yellow when you're close and green when you're clear.", -- luacheck: no max line length
		"In a group, once a mob is fighting the marker shows your threat on it: in Bear Form green means it's safely yours and red that someone else has it, with your lead as a percentage.", -- luacheck: no max line length
		"It learns from the mobs that pull you: a mob you've been pulled by shows its own measured radius (24y*), and after three such pulls the rest use your measured average. Mind Soothe and Soothe Animal count too. /fd pulls shows what it has learned.", -- luacheck: no max line length
	} },
	{ version = "0.5.0", notes = {
		"Reminders can be dismissed: click the trainer, class-quest or talent reminder to clear it, or right-click a buff reminder to hide it for 30 minutes.", -- luacheck: no max line length
		"Druid macros fixed for Forever: shift macros no longer drop you out of your form, FD Prowl takes you into Cat Form and Prowl and back out of Prowl, and the new FD Powershift and FD Opener cover powershifting and the Ravage opener.", -- luacheck: no max line length
		"Tell Forever Druid how you play (levelling, Feral, tank, healer or Balance) and it sets itself up for it. Change it any time from the minimap menu.", -- luacheck: no max line length
		"Right-click any piece while unlocked for its own menu, and the settings now open with an at-a-glance list of every part and how it's doing.", -- luacheck: no max line length
		"Powershift helpers: pips for how many shifts your mana affords, and a Powershift cue in Cat or Bear Form when it's worth it (with Furor).",
		"Click-to-heal party frames (turn on in settings): pick what each click casts, with health, your HoTs and range on every bar.",
		"A form bar to click-shift, item tooltips with what each item's stats do for you compared with what you wear, and a warning when a Growl doesn't take.", -- luacheck: no max line length
		"\"Let it bleed\": when your Rake, Rip, Moonfire or Insect Swarm is ticking on an enemy that's nearly dead, the target row tells you to move on to the next one.", -- luacheck: no max line length
		"A party panel shows your HoTs on each group member, with a Rebirth hint when someone dies and an Innervate hint when a healer runs low.", -- luacheck: no max line length
		"Big alerts for Clearcasting and Nature's Grace, and a warning when you're losing aggro in Bear Form, wherever the game lets addons see them in combat.", -- luacheck: no max line length
		"Missing Faerie Fire, Demoralizing Roar, Moonfire or Insect Swarm on your enemy shows as a dimmed icon next to your effects.",
		"Reminders for unspent talent points, and three more macros: mouseover Faerie Fire, Barkskin from any form, and an emergency Nature's Swiftness into Healing Touch.", -- luacheck: no max line length
		"Your action bars now stay on your highest spell ranks: learn a new rank and every button with the old one switches to it. Downrank on purpose with /fd ranks keep <spell>.", -- luacheck: no max line length
		"An energy bar in Cat Form and a rage bar in Bear Form.",
		"A five-second-rule bar shows when your mana regeneration comes back after a cast.",
		"Choose your caster-form role (healer, Balance or Feral), and a close talent split now counts as Feral.",
		"Reminders for your trainer after levelling up and for the Bear Form and Cat Form class quests. Optional reagent restock at vendors.",
		"Druid macros made for you: shift-out heals, mouseover buffs, Maul and Claw with auto-attack, powershifting, mouseover Roots and Rebirth. Turn them on in the new Macros settings page, then pick one up and drop it on your bar. New ones appear as you learn the spells, and any you edit are left alone.", -- luacheck: no max line length
		"Unlocking now fills empty rows with sample icons, so you can see what you're arranging.",
		"Cooldowns flash when they're ready again, dim when you can't use them, turn blue when you're short on mana, rage or energy, and red when your target is out of range.", -- luacheck: no max line length
		"Choose a minimal or a Blizzard-style look for every icon.",
		"The mana bar glides to its new value instead of jumping.",
		"Move a piece one pixel at a time with the arrow keys while unlocked (hold Shift for ten), and turn on an alignment grid.",
		"Keybindings for unlock, quick settings and all settings, under Key Bindings > AddOns.",
		"Share a layout: copy your profile as text and paste it on another character, account or for a friend.",
		"Each part of the HUD has its own settings page, every option explains itself when you hover it, and resets ask first.",
		"German, French and Spanish translations of the menus, settings and welcome tour.",
	} },
	{ version = "0.4.0", notes = {
		"A druid icon on the minimap opens quick settings: what's shown, size, fading, forms, reminders and profiles.",
	} },
	{ version = "0.3.0", notes = {
		"The HUD lines itself up under your character and closes up when you change form.",
	} },
}

-- "0.10.2" > "0.9.9": compares dotted numbers; anything unparsable sorts lowest.
function ns.CompareVersions(a, b)
	local function Parts(v)
		local out = {}
		for n in tostring(v or ""):gmatch("%d+") do
			out[#out + 1] = tonumber(n)
		end
		return out
	end
	local pa, pb = Parts(a), Parts(b)
	for i = 1, math.max(#pa, #pb) do
		local x, y = pa[i] or 0, pb[i] or 0
		if x ~= y then
			return x < y and -1 or 1
		end
	end
	return 0
end

-- Notes for every version newer than `since` (all of them when since is nil), newest first.
function ns.NotesSince(since)
	local out = {}
	for _, release in ipairs(ns.RELEASE_NOTES) do
		if not since or ns.CompareVersions(release.version, since) > 0 then
			if ns.CompareVersions(release.version, ns.VERSION) <= 0 or ns.VERSION == "dev" then
				out[#out + 1] = release
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------

local function Window(name, title, width, height)
	local frame = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(width, height)
	frame:SetPoint("CENTER", 0, 120)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	-- Forever's BasicFrameTemplate has no title text of its own; put ours in its title bar.
	local titleText = rawget(frame, "TitleText")
	if not titleText then
		titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		titleText:SetPoint("TOP", 0, -5)
		frame.TitleText = titleText
	end
	titleText:SetText(title)
	if UISpecialFrames then
		table.insert(UISpecialFrames, name) -- Esc closes it
	end
	local body = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	body:SetPoint("TOPLEFT", 18, -36)
	body:SetPoint("TOPRIGHT", -18, -36)
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")
	body:SetSpacing(4)
	frame.body = body
	return frame
end
ns.Window = Window

local function Button(parent, label, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 120, 24)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	return button
end
ns.WindowButton = Button

local function Bullets(lines)
	local out = {}
	for _, line in ipairs(lines) do
		out[#out + 1] = "|cffff7d0a-|r " .. line
	end
	return table.concat(out, "\n\n")
end

local tour
function ns.ShowTour()
	if not tour then
		tour = Window("ForeverDruidTour", L["Welcome to Forever Druid"], 460, 330)
		tour.body:SetText(Bullets({
			L["Your druid HUD sits under your character. It lines itself up and changes with your form: mana and combo points in Cat Form, rage tools in Bear Form, healing cooldowns in caster form."], -- luacheck: no max line length
			L["Click the cat icon on your minimap for quick settings. Right-click it to unlock, then drag any piece to move the whole HUD."],
			L["Shift-click the icon, or type /fd config, for every setting."],
			L["Reminders above your character show missing buffs and low reagents. Click one to cast it."],
		}))
		local showMe = Button(tour, L["Show me"], 120, function()
			tour:Hide()
			ns.SetUnlocked(true)
			ns.Print(L["unlocked: drag any green box to move the whole HUD, shift-drag one to give it its own spot, then /fd lock"])
		end)
		showMe:SetPoint("BOTTOMRIGHT", -16, 14)
		local gotIt = Button(tour, L["Got it"], 100, function()
			tour:Hide()
		end)
		gotIt:SetPoint("RIGHT", showMe, "LEFT", -8, 0)
		tour:SetScript("OnHide", function()
			ns.global.tourSeen = true
		end)
	end
	tour:Show()
	return tour
end

local whatsNew
function ns.ShowWhatsNew(since)
	local releases = ns.NotesSince(since)
	if #releases == 0 then
		releases = { ns.RELEASE_NOTES[1] }
	end
	if not whatsNew then
		whatsNew = Window("ForeverDruidWhatsNew", L["What's new in Forever Druid"], 480, 380)
		local close = Button(whatsNew, L["Nice"], 100, function()
			whatsNew:Hide()
		end)
		close:SetPoint("BOTTOMRIGHT", -16, 14)
	end
	local sections = {}
	for _, release in ipairs(releases) do
		local notes = {}
		for _, note in ipairs(release.notes) do
			notes[#notes + 1] = L[note]
		end
		sections[#sections + 1] = "|cffffd100" .. release.version .. "|r\n" .. Bullets(notes)
	end
	whatsNew.body:SetText(table.concat(sections, "\n\n"))
	whatsNew.releases = releases
	whatsNew:Show()
	return whatsNew
end

---------------------------------------------------------------------------
-- Play styles: one choice that switches on the parts that matter and off the rest
---------------------------------------------------------------------------

local ALL_PARTS = { "targetauras", "powerbar", "manabar", "fsr", "combopoints", "powershift", "cooldowns",
	"buffs", "reminders", "alerts", "party", "healframes", "formbar", "aggroradius" }

ns.PLAYSTYLES = {
	{ key = "leveling", label = "Levelling (a bit of everything)", role = "auto",
		desc = "Cat and Bear tools, healing cooldowns in caster form, reminders and trainer prompts. The default.",
		off = { "healframes", "formbar" },
		macros = { "rejuv", "regrowth", "mark", "thorns", "maul", "claw", "shiftCat", "shiftBear", "faerie", "roots",
			"rebirth", "prowl", "nextTarget", "healWrath", "travel", "sootheAnimal" } },
	{ key = "feral", label = "Feral damage (Cat Form)", role = "feral",
		desc = "Energy, combo points, powershifting, bleeds and Let it bleed. Healing extras off.",
		off = { "party", "healframes", "fsr", "formbar" },
		macros = { "claw", "shiftCat", "shiftBear", "powershift", "reshift", "faerie", "prowl", "opener", "rejuv", "mark", "thorns",
			"pounce", "dash", "feralCharge", "berserk", "trinkets" } },
	{ key = "bear", label = "Tank (Bear Form)", role = "feral",
		desc = "Rage, tanking cooldowns, aggro and Growl warnings, Demoralizing Roar and Faerie Fire upkeep.",
		off = { "healframes", "fsr", "combopoints", "formbar" },
		macros = { "maul", "shiftBear", "reshift", "bearRejuv", "faerie", "barkskin", "mark", "thorns", "rejuv",
			"growl", "lacerate", "primalBite", "swipe", "feralCharge", "bearPotion", "bash", "berserk", "trinkets" } },
	{ key = "healer", label = "Healer (Restoration)", role = "healer",
		desc = "Click-to-heal frames, HoT tracker, Innervate and Rebirth hints, the five-second rule. Feral parts off.",
		off = { "powerbar", "combopoints", "powershift", "formbar" },
		macros = { "rejuv", "regrowth", "healingTouch", "swiftHeal", "innervate", "rebirth", "mark", "thorns", "barkskin",
			"wildGrowth", "spiritInnervate", "stonePotion", "cleanse" } },
	{ key = "balance", label = "Balance (caster damage)", role = "balance",
		desc = "Nature's Grace and Clearcasting alerts, Moonfire and Insect Swarm upkeep, the five-second rule.",
		off = { "powerbar", "combopoints", "powershift", "healframes", "formbar" },
		macros = { "faerie", "roots", "hibernate", "innervate", "rebirth", "rejuv", "mark", "thorns", "barkskin",
			"moonkin", "hurricane", "moonfire", "insectSwarm", "sootheAnimal", "stonePotion", "cleanse" } },
}
local PLAYSTYLE_BY_KEY = {}
for _, style in ipairs(ns.PLAYSTYLES) do
	PLAYSTYLE_BY_KEY[style.key] = style
end

-- Applies a play style. Returns false if it has to wait for combat to end (secure parts).
function ns.ApplyPlaystyle(key, withMacros)
	local style = PLAYSTYLE_BY_KEY[key]
	if not style then
		return false
	end
	if InCombatLockdown() then
		ns.Print(L["play styles can't be changed during combat"])
		return false
	end
	local off = {}
	for _, part in ipairs(style.off) do
		off[part] = true
	end
	for _, part in ipairs(ALL_PARTS) do
		if ns.modules[part] then
			ns.SetModuleEnabled(part, not off[part])
		end
	end
	ns.db.role = style.role
	ns.db.playstyle = key
	if ns.UpdateRole then
		ns.UpdateRole()
	end
	if withMacros and ns.macros then
		local wanted = {}
		for _, m in ipairs(style.macros) do
			wanted[m] = true
		end
		for _, def in ipairs(ns.macros.LIST) do
			ns.db.macros.enabled[def.key] = wanted[def.key] or false
		end
		ns.macros.SetManaged(true)
	end
	ns.Print(L["play style"] .. ": " .. L[style.label])
	ns.Fire("FD_PLAYSTYLE_CHANGED", key)
	return true
end

local chooser
function ns.ShowPlaystyle(thenTour)
	if not chooser then
		chooser = Window("ForeverDruidPlaystyle", L["How do you play?"], 470, 410)
		chooser.body:SetText(L["Pick the closest; it only decides which parts of the HUD are on. You can change any of it later, or pick again from the minimap menu."]) -- luacheck: no max line length
		local macros = CreateFrame("CheckButton", nil, chooser, "UICheckButtonTemplate")
		macros:SetPoint("BOTTOMLEFT", 14, 12)
		macros:SetChecked(true)
		local macroText = chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		macroText:SetPoint("LEFT", macros, "RIGHT", 2, 0)
		macroText:SetText(L["Also create the matching druid macros"])
		chooser.macros = macros
		chooser.buttons = {}
		for i, style in ipairs(ns.PLAYSTYLES) do
			local button = Button(chooser, L[style.label], 300, function()
				chooser:Hide()
				ns.ApplyPlaystyle(style.key, chooser.macros:GetChecked() and true or false)
				if chooser.thenTour then
					chooser.thenTour = nil
					ns.ShowTour()
				end
			end)
			button:SetPoint("TOP", chooser, "TOP", 0, -78 - (i - 1) * 56)
			local desc = chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			desc:SetPoint("TOP", button, "BOTTOM", 0, -2)
			desc:SetWidth(420)
			desc:SetText(L[style.desc])
			chooser.buttons[style.key] = button
		end
		chooser:SetScript("OnHide", function()
			ns.global.playstyleSeen = true
			if chooser.thenTour then
				chooser.thenTour = nil
				ns.ShowTour()
			end
		end)
	end
	chooser.thenTour = thenTour
	chooser:Show()
	return chooser
end

---------------------------------------------------------------------------
-- Confirmation popup
---------------------------------------------------------------------------

-- Asks first, then runs `onAccept`. Falls back to running it straight away if popups are missing.
function ns.Confirm(text, onAccept)
	if not (StaticPopupDialogs and StaticPopup_Show) then
		onAccept()
		return
	end
	if not StaticPopupDialogs.FOREVERDRUID_CONFIRM then
		StaticPopupDialogs.FOREVERDRUID_CONFIRM = {
			text = "%s",
			button1 = YES or "Yes",
			button2 = NO or "No",
			OnAccept = function(_, data)
				if data then
					data()
				end
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	StaticPopup_Show("FOREVERDRUID_CONFIRM", text, nil, onAccept)
end

---------------------------------------------------------------------------
-- When to show them
---------------------------------------------------------------------------

local pending

local function ShowPending()
	if not pending then
		return
	end
	if InCombatLockdown() then
		return -- PLAYER_REGEN_ENABLED tries again
	end
	local what = pending
	pending = nil
	if what.tour then
		if not ns.global.playstyleSeen then
			ns.ShowPlaystyle(true) -- the tour follows once a style is picked or the window closed
		else
			ns.ShowTour()
		end
	elseif what.since then
		ns.ShowWhatsNew(what.since)
	end
end

ns.Listen("FD_LOGIN", function()
	if not ns.isDruid then
		return
	end
	-- Read before Core records this version as seen.
	local previous = ns.global.lastVersion
	if not previous then
		if not ns.global.tourSeen then
			pending = { tour = true }
		end
	else
		ns.global.tourSeen = true -- upgraded from before the tour existed; they know their way around
		if previous ~= ns.VERSION and #ns.NotesSince(previous) > 0 then
			pending = { since = previous }
		end
	end
	if pending then
		C_Timer.After(4, ShowPending)
	end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
	if pending then
		C_Timer.After(1, ShowPending)
	end
end)
