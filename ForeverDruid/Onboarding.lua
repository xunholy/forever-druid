-- First-login welcome, "What's new" after an update, and the confirmation popup other files use.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Release notes: written for players, newest first. Shown once after updating.
---------------------------------------------------------------------------

ns.RELEASE_NOTES = {
	{ version = "0.5.0", notes = {
		"Next ability: if Forever offers Blizzard's rotation suggestion, ForeverDruid shows your next ability by the HUD and makes its button glow.",
		"\"Let it bleed\": when your Rake, Rip, Moonfire or Insect Swarm is ticking on an enemy that's nearly dead, the target row tells you to move on to the next one.", -- luacheck: no max line length
		"A party panel shows your HoTs on each group member, with a Rebirth hint when someone dies and an Innervate hint when a healer runs low.", -- luacheck: no max line length
		"Big alerts for Clearcasting and Nature's Grace, and a warning when you're losing aggro in Bear Form, wherever the game lets addons see them in combat.", -- luacheck: no max line length
		"Missing Faerie Fire, Demoralizing Roar, Moonfire or Insect Swarm on your enemy shows as a dimmed icon next to your effects.",
		"Reminders for unspent talent points, and three more macros: mouseover Faerie Fire, Barkskin from any form, and an emergency Nature's Swiftness into Healing Touch.", -- luacheck: no max line length
		"Your action bars now stay on your highest spell ranks: learn a new rank and every button with the old one switches to it. Downrank on purpose with /fd ranks keep <spell>.", -- luacheck: no max line length
		"An energy bar in Cat Form and a rage bar in Bear Form, with the energy tick spark right on the bar.",
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
		tour = Window("ForeverDruidTour", L["Welcome to ForeverDruid"], 460, 330)
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
		whatsNew = Window("ForeverDruidWhatsNew", L["What's new in ForeverDruid"], 480, 380)
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
		ns.ShowTour()
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
