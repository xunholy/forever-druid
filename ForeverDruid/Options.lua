-- Slash commands and the Options > AddOns > ForeverDruid panel.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function Status()
	ns.Print(("v%s - %s %s, %s %s, %s %s, %s %s"):format(ns.VERSION,
		L["form"], tostring(ns.form), L["talents"], tostring(ns.tree or L["none"]),
		L["role"], tostring(ns.role), L["profile"], tostring(ns.profileName)))
	if not ns.isDruid then
		ns.Print(L["Not a druid: modules are off. /fd probe still works."])
		return
	end
	local cpu = ns.CpuSummary and ns.CpuSummary()
	if cpu then
		ns.Print("  " .. cpu)
	end
	for _, key in ipairs(ns.moduleOrder) do
		ns.Print(("  %s: %s"):format(key, ns.db.modules[key].enabled and L["on"] or L["off"]))
	end
end

local function Help()
	ns.Print(L["commands:"])
	ns.Print("  /fd config - " .. L["options panel"])
	ns.Print("  /fd unlock | lock - " .. L["move the HUD"])
	ns.Print("  /fd reset - " .. L["default positions"])
	ns.Print("  /fd stack on | off - " .. L["stack the HUD into one column automatically"])
	ns.Print("  /fd minimap - " .. L["show or hide the minimap button"])
	ns.Print("  /fd ranks [on | off | now | keep <spell> | unkeep <spell>] - " .. L["keep action bars on your highest spell ranks"])
	ns.Print("  /fd grid - " .. L["alignment grid while unlocked"])
	ns.Print("  /fd macros [on | off | sync | restore] - " .. L["create and manage druid macros"])
	ns.Print("  /fd tour | whatsnew - " .. L["the welcome tour, or what changed recently"])
	ns.Print("  /fd toggle <module> - manabar, energytick, combopoints, cooldowns, buffs, targetauras, reminders")
	ns.Print("  /fd cd add|remove <role|all> <spell> - " .. L["track extra cooldowns"])
	ns.Print("  /fd cd list")
	ns.Print("  /fd profile [list | use <name> | copy <name> | reset | delete <name> | export | import]")
	ns.Print("  /fd status - " .. L["form, talents, role and modules"])
	ns.Print("  /fd probe - " .. L["record what this client exposes"])
end

local function ProfileCommand(rest)
	local action, name = strsplit(" ", rest or "", 2)
	action = strlower(action or "")
	name = name and strtrim(name) or nil
	if action == "" or action == "list" then
		ns.Print(L["profile"] .. ": " .. ns.profileName .. "  (" .. table.concat(ns.ProfileNames(), ", ") .. ")")
	elseif action == "use" and name and name ~= "" then
		ns.UseProfile(name)
		ns.Print(L["switched to profile"] .. " " .. name .. " - /reload " .. L["to apply"])
	elseif action == "copy" and name and name ~= "" then
		if ns.CopyProfileFrom(name) then
			ns.Print(L["copied"] .. " " .. name .. " - /reload " .. L["to apply"])
		else
			ns.Print(L["no profile named"] .. " " .. name)
		end
	elseif action == "export" then
		ns.ShowShareWindow("export")
	elseif action == "import" then
		ns.ShowShareWindow("import")
	elseif action == "reset" then
		ns.ResetProfile()
		ns.Print(L["profile reset"] .. " - /reload " .. L["to apply"])
	elseif action == "delete" and name and name ~= "" then
		if ns.DeleteProfile(name) then
			ns.Print(L["deleted"] .. " " .. name)
		else
			ns.Print(L["can't delete the active profile or a missing one"])
		end
	else
		Help()
	end
end

local function CooldownCommand(rest)
	local action, role, name = strsplit(" ", rest or "", 3)
	action = strlower(action or "")
	role = role and strlower(role) or nil
	if action ~= "add" and action ~= "remove" and action ~= "list" then
		Help()
		return
	end
	ns.Print(ns.modules.cooldowns.EditExtra(action, role, name and strtrim(name)))
	if ns.modules.cooldowns.enabled then
		ns.modules.cooldowns:Refresh()
	end
end

-- Key Bindings > AddOns > ForeverDruid (Bindings.xml calls these).
BINDING_HEADER_FOREVERDRUID = "ForeverDruid"
BINDING_NAME_FOREVERDRUID_UNLOCK = L["Unlock / lock the HUD"]
BINDING_NAME_FOREVERDRUID_MENU = L["Quick settings menu"]
BINDING_NAME_FOREVERDRUID_OPTIONS = L["All settings"]

function ForeverDruid_ToggleUnlock()
	if ns.db and ns.isDruid and ns.SetUnlocked(not ns.db.unlocked) then
		ns.Print(ns.db.unlocked and L["unlocked: drag any green box to move the whole HUD, shift-drag one to give it its own spot, then /fd lock"] or L["locked"])
	end
end

function ForeverDruid_OpenQuickMenu()
	if ns.db and ns.isDruid and ns.OpenQuickMenu then
		ns.OpenQuickMenu()
	end
end

function ForeverDruid_OpenOptions()
	ns.OpenOptions()
end

SLASH_FOREVERDRUID1 = "/fd"
SLASH_FOREVERDRUID2 = "/foreverdruid"
SlashCmdList.FOREVERDRUID = function(input)
	local command, rest = strsplit(" ", strtrim(input or ""), 2)
	command = strlower(command or "")
	if command == "unlock" then
		if ns.SetUnlocked(true) then
			ns.Print(L["unlocked: drag any green box to move the whole HUD, shift-drag one to give it its own spot, then /fd lock"])
		end
	elseif command == "lock" then
		if ns.SetUnlocked(false) then
			ns.Print(L["locked"])
		end
	elseif command == "reset" then
		if ns.ResetPositions() then
			ns.Print(L["positions reset"])
		end
	elseif command == "stack" then
		local value = rest and strlower(strtrim(rest)) or ""
		local enabled
		if value == "on" then
			enabled = true
		elseif value == "off" then
			enabled = false
		else
			enabled = not ns.db.layout.stack
		end
		ns.SetStackEnabled(enabled)
		ns.Print(L["automatic stack"] .. " " .. (ns.db.layout.stack and L["on"] or L["off"]))
	elseif command == "macros" or command == "macro" then
		if not ns.isDruid then
			ns.Print(L["Not a druid: modules are off. /fd probe still works."])
			return
		end
		local action = rest and strlower(strtrim(rest)) or ""
		if action == "on" or action == "off" then
			ns.macros.SetManaged(action == "on")
		elseif action == "sync" or action == "update" then
			local _, result = ns.macros.Sync()
			ns.macros.Report(result)
		elseif action == "restore" then
			ns.Print(L["restored"] .. " " .. ns.macros.Restore())
		else
			ns.Print(L["macros"] .. ": " .. (ns.db.macros.manage and L["on"] or L["off"]) .. "  (/fd macros on | off | sync | restore)")
			for _, def in ipairs(ns.macros.LIST) do
				ns.Print(("  %s - %s"):format(def.name, (ns.MacroStatusText(def.key))))
			end
		end
	elseif command == "ranks" or command == "rank" then
		if not ns.isDruid then
			ns.Print(L["Not a druid: modules are off. /fd probe still works."])
			return
		end
		local action, spell = strsplit(" ", rest or "", 2)
		action = strlower(action or "")
		spell = spell and strtrim(spell) or nil
		if action == "on" or action == "off" then
			ns.db.ranks.auto = action == "on"
			ns.Print(L["highest-rank action bars"] .. " " .. (ns.db.ranks.auto and L["on"] or L["off"]))
		elseif action == "keep" and spell and spell ~= "" then
			ns.ranks.SetKept(spell, true)
			ns.Print(spell .. ": " .. L["left at the rank you put on your bars"])
		elseif action == "unkeep" and spell and spell ~= "" then
			ns.ranks.SetKept(spell, false)
			ns.Print(spell .. ": " .. L["kept at the highest rank again"])
		elseif action == "now" or action == "update" then
			local done = ns.ranks.Upgrade()
			if done == 0 then
				ns.Print(L["every spell on your bars is already the highest rank"])
			end
		else
			local kept = ns.ranks.KeptList()
			ns.Print(L["highest-rank action bars"] .. ": " .. (ns.db.ranks.auto and L["on"] or L["off"])
				.. (#kept > 0 and ("  (" .. L["kept"] .. ": " .. table.concat(kept, ", ") .. ")") or ""))
			ns.Print("  /fd ranks on | off | now | keep <spell> | unkeep <spell>")
		end
	elseif command == "grid" then
		ns.db.grid = not ns.db.grid
		ns.UpdateGrid()
		ns.Print(L["alignment grid"] .. " " .. (ns.db.grid and L["on"] or L["off"]) .. (ns.db.unlocked and "" or (" - " .. L["shows while unlocked"])))
	elseif command == "tour" then
		ns.ShowTour()
	elseif command == "whatsnew" or command == "news" then
		ns.ShowWhatsNew()
	elseif command == "minimap" then
		if not ns.isDruid then
			ns.Print(L["Not a druid: modules are off. /fd probe still works."])
			return
		end
		if not ns.SetMinimapButtonShown then
			-- The client reads an addon's file list only at startup.
			ns.Print(L["restart the game (not just /reload) to load the minimap button"])
			return
		end
		ns.SetMinimapButtonShown(ns.db.minimap.hide)
		ns.Print(L["minimap button"] .. " " .. (ns.db.minimap.hide and L["hidden"] or L["shown"]))
	elseif command == "toggle" then
		local key = rest and strlower(strtrim(rest))
		local cfg = key and ns.db.modules[key]
		if not cfg then
			ns.Print(L["unknown module"])
			return
		end
		ns.SetModuleEnabled(key, not cfg.enabled)
		ns.Print(("%s %s"):format(key, ns.db.modules[key].enabled and L["on"] or L["off"]))
	elseif command == "cd" then
		CooldownCommand(rest)
	elseif command == "profile" then
		ProfileCommand(rest)
	elseif command == "status" then
		Status()
	elseif command == "probe" then
		ns.PrintSnapshot(ns.TakeSnapshot("manual"))
	elseif command == "config" or command == "options" then
		ns.OpenOptions()
	else
		Help()
	end
end

---------------------------------------------------------------------------
-- Options panel
---------------------------------------------------------------------------

local panelCategory

function ns.OpenOptions(category)
	category = category or panelCategory
	if category and Settings and Settings.OpenToCategory then
		local id = category.GetID and category:GetID() or category.ID
		if id then
			Settings.OpenToCategory(id)
			return
		end
	end
	ns.Print(L["Open Options > AddOns > ForeverDruid."])
end

-- Layout helper: widgets stack top to bottom inside a scroll child. Every widget takes an
-- optional tooltip as its last argument.
local Builder = {}
Builder.__index = Builder

local widgetCount = 0

local function NewBuilder(content)
	return setmetatable({ content = content, y = -16, refreshers = {} }, Builder)
end

local function Tip(widget, label, text)
	if not text then
		return
	end
	widget:SetScript("OnEnter", function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label, 1, 0.82, 0)
			GameTooltip:AddLine(text, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	widget:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

function Builder:Space(amount)
	self.y = self.y - (amount or 8)
end

function Builder:Header(text)
	self:Space(10)
	local header = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", 16, self.y)
	header:SetText(text)
	self.y = self.y - 24
	local line = self.content:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.49, 0.04, 0.5)
	line:SetPoint("TOPLEFT", 16, self.y + 4)
	line:SetSize(560, 1)
end

function Builder:Note(text)
	local note = self.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", 20, self.y)
	note:SetWidth(540)
	note:SetJustifyH("LEFT")
	note:SetText(text)
	-- Long notes wrap; leave room for every line.
	local height = note.GetStringHeight and note:GetStringHeight()
	self.y = self.y - math.max(18, (tonumber(height) or 0) + 6)
	return note
end

function Builder:Check(label, get, set, tip)
	local check = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", 16, self.y)
	local text = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetText(label)
	check:SetScript("OnClick", function(widget)
		set(widget:GetChecked() and true or false)
	end)
	Tip(check, label, tip)
	self.refreshers[#self.refreshers + 1] = function()
		check:SetChecked(get() and true or false)
	end
	self.y = self.y - 28
	return check
end

function Builder:Slider(label, minValue, maxValue, step, get, set, tip)
	widgetCount = widgetCount + 1
	local name = "ForeverDruidOptionsSlider" .. widgetCount
	local slider = CreateFrame("Slider", name, self.content, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 24, self.y - 14)
	slider:SetWidth(240)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	local low, high, title = _G[name .. "Low"], _G[name .. "High"], _G[name .. "Text"]
	if low then
		low:SetText(tostring(minValue))
	end
	if high then
		high:SetText(tostring(maxValue))
	end
	local function Label(value)
		if title then
			title:SetText(("%s: %s"):format(label, step < 1 and ("%.2f"):format(value) or tostring(math.floor(value + 0.5))))
		end
	end
	slider:SetScript("OnValueChanged", function(_, value, userInput)
		Label(value)
		if userInput then
			set(value)
		end
	end)
	Tip(slider, label, tip)
	self.refreshers[#self.refreshers + 1] = function()
		local value = get()
		slider:SetValue(value)
		Label(value)
	end
	self.y = self.y - 46
	return slider
end

function Builder:Button(label, width, onClick, tip)
	local button = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
	button:SetSize(width or 160, 22)
	button:SetPoint("TOPLEFT", 20, self.y)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	Tip(button, label, tip)
	self.y = self.y - 28
	return button
end

function Builder:Cycle(label, values, get, set, tip)
	local button = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
	button:SetSize(220, 22)
	button:SetPoint("TOPLEFT", 20, self.y)
	local function Render()
		button:SetText(("%s: %s"):format(label, L[get()]))
	end
	button:SetScript("OnClick", function()
		local current = get()
		local index = 1
		for i, value in ipairs(values) do
			if value == current then
				index = i % #values + 1
			end
		end
		set(values[index])
		Render()
	end)
	Tip(button, label, tip)
	self.refreshers[#self.refreshers + 1] = Render
	self.y = self.y - 28
	return button
end

function Builder:Refresh()
	for _, refresh in ipairs(self.refreshers) do
		local ok, err = pcall(refresh)
		if not ok then
			ns.ReportError(err)
		end
	end
end

local function ModuleSetter(module, field, refresh)
	return function(value)
		ns.db.modules[module][field] = value
		if refresh == "scale" then
			ns.ApplyScales()
		end
		local m = ns.modules[module]
		if m and m.enabled and m.Refresh then
			m:Refresh()
		end
	end
end

local function ModuleGetter(module, field)
	return function()
		return ns.db.modules[module][field]
	end
end

local MODULE_TITLES = {
	powerbar = "Energy / rage",
	fsr = "Five-second rule",
	manabar = "Mana bar",
	energytick = "Energy tick",
	combopoints = "Combo points",
	cooldowns = "Cooldowns",
	buffs = "Buffs & procs",
	targetauras = "My effects on target",
	reminders = "Reminders",
}
ns.MODULE_TITLES = MODULE_TITLES

local MODULE_NOTES = {
	powerbar = "Energy in Cat Form and rage in Bear Form, with the energy tick spark on the bar.",
	fsr = "After you spend mana, your normal mana regeneration pauses for five seconds. This bar fills over those five seconds.",
	manabar = "Your mana while in Cat or Bear Form, with the cost of one shift marked.",
	energytick = "Learns Forever's energy ticks in Cat Form and sweeps a spark to the next one.",
	combopoints = "Five pips that turn red at five points.",
	cooldowns = "Cooldowns for what you're doing right now, limited to spells you know.",
	buffs = "Clearcasting, Tiger's Fury, Barkskin, Enrage and other buffs, with timers.",
	targetauras = "Your DoTs on an enemy target or your HoTs on a friendly one.",
	reminders = "Out of combat only. Click a buff reminder to cast it.",
}

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

local pageCount = 0

-- One scrolling page. Returns its frame and a builder; call Finish(builder) when it's filled.
local function NewPage(name, title, subtitle)
	pageCount = pageCount + 1
	local panel = CreateFrame("Frame")
	panel.name = name
	local scroll = CreateFrame("ScrollFrame", "ForeverDruidOptionsScroll" .. pageCount, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(600, 1)
	scroll:SetScrollChild(content)
	local b = NewBuilder(content)
	local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
	heading:SetPoint("TOPLEFT", 16, b.y)
	heading:SetText(title)
	b.y = b.y - 34
	if subtitle then
		b:Note(subtitle)
	end
	b.panel = panel
	return panel, b
end

local function Finish(b)
	b.content:SetHeight(-b.y + 20)
	b.panel:SetScript("OnShow", function()
		b:Refresh()
	end)
end

local function ConfirmReset()
	ns.Confirm(L["Put every piece of the HUD back in its default place?"], function()
		if ns.ResetPositions() then
			ns.Print(L["positions reset"])
		end
	end)
end
ns.ConfirmResetPositions = ConfirmReset

local function MainPage()
	local panel, b = NewPage("ForeverDruid", "ForeverDruid |cffffffff" .. ns.VERSION .. "|r",
		L["A druid HUD for WoW Forever. Each part of the HUD has its own page in the list on the left."])

	b:Header(L["Moving things"])
	b:Button(L["Unlock / lock"], 160, function()
		ns.SetUnlocked(not ns.db.unlocked)
	end, L["Unlocked, every piece shows a green box you can drag. Arrow keys nudge the piece under your mouse by one pixel (Shift: ten)."])
	b:Button(L["Reset positions"], 160, ConfirmReset, L["Puts every piece back in its default place and back in the stack. Asks first."])
	b:Check(L["Stack the HUD automatically"], function()
		return ns.db.layout.stack
	end, function(value)
		ns.SetStackEnabled(value)
	end, L["One column under your character that closes up when a piece is hidden. Drag any piece to move it all; shift-drag a piece to give it its own spot."])
	b:Slider(L["Space between stacked pieces"], 0, 20, 1, function()
		return ns.db.layout.gap
	end, function(value)
		ns.db.layout.gap = value
		ns.LayoutStack()
	end, L["Gap in pixels between the pieces of the stack."])
	b:Check(L["Sample icons while unlocked"], function()
		return ns.db.preview
	end, function(value)
		ns.db.preview = value
		ns.Fire("FD_LOCK_CHANGED", ns.db.unlocked)
	end, L["Fills empty rows with example buffs, DoTs, combo points and reminders while unlocked, so you can see what you're arranging."])
	b:Check(L["Alignment grid while unlocked"], function()
		return ns.db.grid
	end, function(value)
		ns.db.grid = value
		ns.UpdateGrid()
	end, L["Shows a grid with the screen centre marked while the HUD is unlocked."])

	b:Header(L["Look"])
	b:Cycle(L["Icon style"], ns.ICON_STYLES, function()
		return ns.db.style.icons
	end, function(value)
		ns.db.style.icons = value
		ns.RestyleAll()
	end, L["minimal: icons cropped with a thin black frame. blizzard: the icon's own border, like action bars."])
	b:Slider(L["Overall scale"], 0.5, 2, 0.05, function()
		return ns.db.scale
	end, function(value)
		ns.db.scale = value
		ns.ApplyScales()
	end, L["Size of the whole HUD. Each part also has its own scale on its page."])
	b:Slider(L["Opacity out of combat"], 0, 1, 0.05, function()
		return ns.db.fadeOutOfCombat
	end, function(value)
		ns.db.fadeOutOfCombat = value
		ns.UpdateVisibility()
	end, L["How visible the HUD is outside a fight. It's always fully visible in combat."])
	b:Check(L["Hide while mounted"], function()
		return ns.db.hideWhenMounted
	end, function(value)
		ns.db.hideWhenMounted = value
		ns.UpdateVisibility()
	end, L["Hides the HUD and reminders while you're mounted. It's also hidden while dead, on a taxi or in a vehicle."])
	b:Check(L["Show the minimap button"], function()
		return not ns.db.minimap.hide
	end, function(value)
		if ns.SetMinimapButtonShown then
			ns.SetMinimapButtonShown(value)
		else
			ns.db.minimap.hide = not value
		end
	end, L["The cat icon on the minimap: left-click for quick settings, right-click to unlock, shift-click for this panel. ForeverDruid is also in the minimap addon menu."]) -- luacheck: no max line length

	b:Header(L["Role"])
	b:Cycle(L["In caster form I'm a"], ns.CASTER_ROLES, function()
		return ns.db.role
	end, function(value)
		ns.db.role = value
		ns.UpdateRole()
	end, L["Decides which cooldowns show in caster form. auto: from where your talent points are (Feral wins a close call). Cat and Bear Form always show their own."]) -- luacheck: no max line length

	b:Header(L["Spells"])
	b:Check(L["Keep my action bars on the highest rank"], function()
		return ns.db.ranks.auto
	end, function(value)
		ns.db.ranks.auto = value
		if value then
			ns.ranks.Upgrade()
		end
	end, L["When you learn a new rank, every button with an older rank of that spell is switched to it (out of combat). To keep a spell downranked on purpose: /fd ranks keep <spell>."]) -- luacheck: no max line length

	b:Header(L["Profiles"])
	b:Note(L["Current profile:"] .. " |cffffd100" .. tostring(ns.profileName) .. "|r. " .. L["Switch or create profiles with /fd profile use <name>."])
	b:Button(L["Share this profile..."], 180, function()
		ns.ShowShareWindow("export")
	end, L["Gives you a text string of this profile to paste on another character, another account or for a friend."])
	b:Button(L["Import a profile..."], 180, function()
		ns.ShowShareWindow("import")
	end, L["Paste a profile string from someone else. It's added as a new profile; yours isn't changed."])
	b:Button(L["Reset this profile"], 180, function()
		ns.Confirm(L["Reset every ForeverDruid setting in this profile to its default? This reloads your interface."], function()
			ns.ResetProfile()
			ReloadUI()
		end)
	end, L["Puts every setting in the current profile back to its default. Asks first."])

	b:Header(L["Help"])
	b:Button(L["Show the welcome tour"], 180, function()
		ns.ShowTour()
	end)
	b:Button(L["What's new"], 180, function()
		ns.ShowWhatsNew()
	end)
	b:Note(L["Key bindings for unlock, quick settings and this panel are under Key Bindings > AddOns > ForeverDruid."])

	b:Header(L["Diagnostics"])
	b:Check(L["Record probe snapshots automatically"], function()
		return ns.db.probe.auto
	end, function(value)
		ns.db.probe.auto = value
	end, L["At login and at the start of your first fight, saves what the game lets addons see. Helps tune ForeverDruid to Forever."])
	b:Button(L["Take a snapshot now"], 180, function()
		ns.PrintSnapshot(ns.TakeSnapshot("manual"))
	end)
	Finish(b)
	return panel
end

local MODULE_PAGES = {
	powerbar = function(s)
		s:Check(L["Show the number"], ModuleGetter("powerbar", "text"), ModuleSetter("powerbar", "text"),
			L["Your energy or rage as a number on the bar."])
		s:Check(L["Energy tick spark on the bar"], ModuleGetter("powerbar", "tickSpark"), ModuleSetter("powerbar", "tickSpark"),
			L["Draws the energy tick on this bar in Cat Form, and hides the separate energy tick row."])
		s:Check(L["Smooth"], ModuleGetter("powerbar", "smooth"), ModuleSetter("powerbar", "smooth"),
			L["The bar glides to its new value instead of jumping."])
		s:Slider(L["Width"], 80, 400, 5, ModuleGetter("powerbar", "width"), ModuleSetter("powerbar", "width"))
		s:Slider(L["Height"], 4, 30, 1, ModuleGetter("powerbar", "height"), ModuleSetter("powerbar", "height"))
	end,
	fsr = function(s)
		s:Check(L["Hide in Cat and Bear Form"], ModuleGetter("fsr", "casterOnly"), ModuleSetter("fsr", "casterOnly"),
			L["Only show it in caster form. Leave it on in forms if you powershift."])
		s:Slider(L["Width"], 80, 400, 5, ModuleGetter("fsr", "width"), ModuleSetter("fsr", "width"))
		s:Slider(L["Height"], 2, 20, 1, ModuleGetter("fsr", "height"), ModuleSetter("fsr", "height"))
	end,
	manabar = function(s)
		s:Cycle(L["Text"], ns.modules.manabar.TEXT_MODES, ModuleGetter("manabar", "text"), ModuleSetter("manabar", "text"),
			L["What the bar's text shows: your mana, a percentage, both, or nothing."])
		s:Check(L["Colour by mana level"], ModuleGetter("manabar", "colorByLevel"), ModuleSetter("manabar", "colorByLevel"),
			L["Blue when you're fine, orange under a quarter, red when you're nearly out."])
		s:Check(L["Mark the cost of one shift"], ModuleGetter("manabar", "shiftMarker"), ModuleSetter("manabar", "shiftMarker"),
			L["A line on the bar at the mana one shift back into your form costs."])
		s:Check(L["Smooth"], ModuleGetter("manabar", "smooth"), ModuleSetter("manabar", "smooth"),
			L["The bar glides to its new value instead of jumping."])
		s:Check(L["Show in every form"], ModuleGetter("manabar", "alwaysShow"), ModuleSetter("manabar", "alwaysShow"),
			L["Also show it in caster form, where the game's own frame already shows mana."])
		s:Slider(L["Width"], 80, 400, 5, ModuleGetter("manabar", "width"), ModuleSetter("manabar", "width"))
		s:Slider(L["Height"], 4, 30, 1, ModuleGetter("manabar", "height"), ModuleSetter("manabar", "height"))
	end,
	energytick = function(s)
		s:Note(L["Needs a few fights in Cat Form to learn Forever's tick timing; until then it stays hidden."])
		s:Slider(L["Width"], 80, 400, 5, ModuleGetter("energytick", "width"), ModuleSetter("energytick", "width"))
		s:Slider(L["Height"], 2, 20, 1, ModuleGetter("energytick", "height"), ModuleSetter("energytick", "height"))
	end,
	combopoints = function(s)
		s:Check(L["Only in Cat Form"], ModuleGetter("combopoints", "catOnly"), ModuleSetter("combopoints", "catOnly"),
			L["Hide the pips in other forms, where you can't use combo points."])
		s:Slider(L["Pip size"], 6, 30, 1, ModuleGetter("combopoints", "size"), ModuleSetter("combopoints", "size"))
	end,
	cooldowns = function(s)
		s:Check(L["Flash when ready"], ModuleGetter("cooldowns", "pulse"), ModuleSetter("cooldowns", "pulse"),
			L["A quick flash on the icon when a cooldown comes back."])
		s:Check(L["Dim when unusable"], ModuleGetter("cooldowns", "usableTint"), ModuleSetter("cooldowns", "usableTint"),
			L["Grey when you can't use it right now, blue when you're short on mana, rage or energy."])
		s:Check(L["Red when out of range"], ModuleGetter("cooldowns", "rangeTint"), ModuleSetter("cooldowns", "rangeTint"),
			L["Red when your target is out of range for that spell."])
		s:Check(L["Countdown numbers"], ModuleGetter("cooldowns", "showNumbers"), ModuleSetter("cooldowns", "showNumbers"))
		s:Check(L["Tooltips on mouseover"], ModuleGetter("cooldowns", "tooltips"), ModuleSetter("cooldowns", "tooltips"),
			L["Show the spell tooltip when you hover an icon. Off by default so the icons don't catch your mouse."])
		s:Check(L["Include Skyborne racials"], ModuleGetter("cooldowns", "racials"), ModuleSetter("cooldowns", "racials"),
			L["Read Leyline and Walk on Air."])
		s:Check(L["Hide out of combat"], ModuleGetter("cooldowns", "hideOutOfCombat"), ModuleSetter("cooldowns", "hideOutOfCombat"))
		s:Slider(L["Icon size"], 16, 64, 1, ModuleGetter("cooldowns", "size"), ModuleSetter("cooldowns", "size"))
		s:Note(L["Add your own: /fd cd add <role|all> <spell name>"])
	end,
	buffs = function(s)
		s:Note(L["Forever hides buffs from addons during combat. Buffs that were up when the fight started stay, dimmed, until they'd have run out."])
		s:Slider(L["Icon size"], 16, 64, 1, ModuleGetter("buffs", "size"), ModuleSetter("buffs", "size"))
	end,
	targetauras = function(s)
		s:Slider(L["Icon size"], 16, 64, 1, ModuleGetter("targetauras", "size"), ModuleSetter("targetauras", "size"))
		s:Slider(L["Most shown"], 1, 16, 1, ModuleGetter("targetauras", "max"), ModuleSetter("targetauras", "max"))
	end,
	reminders = function(s)
		s:Check(L["Click a reminder to cast it"], ModuleGetter("reminders", "clickToCast"), ModuleSetter("reminders", "clickToCast"))
		s:Check(L["Mark of the Wild"], ModuleGetter("reminders", "markOfTheWild"), ModuleSetter("reminders", "markOfTheWild"))
		s:Check(L["Omen of Clarity (only where it's a castable buff)"], ModuleGetter("reminders", "omenOfClarity"), ModuleSetter("reminders", "omenOfClarity"))
		s:Check(L["Thorns (always)"], ModuleGetter("reminders", "thorns"), ModuleSetter("reminders", "thorns"))
		s:Check(L["Thorns in Bear Form"], ModuleGetter("reminders", "thornsInBear"), ModuleSetter("reminders", "thornsInBear"))
		s:Check(L["Low Rebirth / Gift of the Wild reagents"], ModuleGetter("reminders", "reagents"), ModuleSetter("reminders", "reagents"),
			L["Warns when you have fewer than two of the reagent."])
		s:Check(L["Skyborne: not attuned to a ley line"], ModuleGetter("reminders", "attuned"), ModuleSetter("reminders", "attuned"))
		s:Check(L["Trainer visit after levelling up"], ModuleGetter("reminders", "trainer"), ModuleSetter("reminders", "trainer"),
			L["Shows after each even level until you open a druid trainer."])
		s:Check(L["Bear and Cat Form class quests"], ModuleGetter("reminders", "formQuests"), ModuleSetter("reminders", "formQuests"),
			L["From level 10 (Bear Form) and 20 (Cat Form) until you have the form."])
		s:Header(L["Restock at vendors"])
		s:Check(L["Buy reagents when I open a vendor"], function()
			return ns.db.restock.enabled
		end, function(value)
			ns.db.restock.enabled = value
		end, L["Tops up Rebirth seeds and Gift of the Wild reagents to the amounts below, only from vendors that sell them, and only what you can afford. Off by default because it spends gold."]) -- luacheck: no max line length
		s:Slider(L["Rebirth seeds to carry"], 0, 20, 1, function()
			return ns.db.restock.seeds
		end, function(value)
			ns.db.restock.seeds = math.floor(value + 0.5)
		end)
		s:Slider(L["Gift of the Wild reagents to carry"], 0, 40, 1, function()
			return ns.db.restock.thornroot
		end, function(value)
			ns.db.restock.thornroot = math.floor(value + 0.5)
		end)
	end,
}

local function ModulePage(key)
	local title = L[MODULE_TITLES[key]]
	local panel, b = NewPage(title, title, L[MODULE_NOTES[key]])
	b:Check(L["Enabled"], ModuleGetter(key, "enabled"), function(value)
		ns.SetModuleEnabled(key, value)
	end)
	b:Slider(L["Scale"], 0.5, 2, 0.05, ModuleGetter(key, "scale"), ModuleSetter(key, "scale", "scale"))
	if ns.IsStackable(key) then
		b:Check(L["Part of the stack"], function()
			return not ns.db.layout.detached[key]
		end, function(value)
			ns.SetStacked(key, value)
		end, L["Untick to give this piece its own spot instead of sitting in the column."])
	end
	MODULE_PAGES[key](b)
	Finish(b)
	return panel
end

local MACRO_STATUS = {
	ready = "|cff40ff40" .. L["ready"] .. "|r",
	edited = "|cffffd100" .. L["edited by you, left alone"] .. "|r",
	missing = "|cffaaaaaa" .. L["not created yet"] .. "|r",
	needs = "|cffaaaaaa" .. L["needs"] .. " %s|r",
	off = "|cff808080" .. L["off"] .. "|r",
}

function ns.MacroStatusText(key)
	local status, extra = ns.macros.Status(key)
	local text = MACRO_STATUS[status] or status
	if status == "needs" then
		text = text:format(ns.SpellName(extra) or extra)
	end
	return text, status
end

local function MacrosPage()
	local panel, b = NewPage(L["Macros"], L["Macros"],
		L["ForeverDruid can create druid macros in your character's own macro slots and keep them up to date as you learn spells. It only touches macros named \"FD ...\", and leaves alone any you've edited."]) -- luacheck: no max line length
	b:Check(L["Create and update my druid macros"], function()
		return ns.db.macros.manage
	end, function(value)
		ns.macros.SetManaged(value)
		b:Refresh()
	end, L["Turning this off deletes the FD macros ForeverDruid made (not ones you've edited)."])
	b:Note(L["Click Pick up, then click an action bar slot to place a macro. Unticking a macro deletes it, unless you've edited it."])
	b:Space(4)
	for _, def in ipairs(ns.macros.LIST) do
		local check = b:Check(def.name, function()
			return ns.db.macros.enabled[def.key] ~= false
		end, function(value)
			ns.macros.SetWanted(def.key, value)
			b:Refresh()
		end, L[def.desc])
		local status = b.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		status:SetPoint("LEFT", check, "LEFT", 150, 0)
		local pick = CreateFrame("Button", nil, b.content, "UIPanelButtonTemplate")
		pick:SetSize(90, 20)
		pick:SetPoint("LEFT", check, "LEFT", 440, 0)
		pick:SetText(L["Pick up"])
		pick:SetScript("OnClick", function()
			ns.macros.PickUp(def.key)
		end)
		b.refreshers[#b.refreshers + 1] = function()
			local text, state = ns.MacroStatusText(def.key)
			status:SetText(text)
			pick:SetEnabled(state == "ready" or state == "edited")
		end
	end
	b:Space(6)
	b:Button(L["Restore edited macros"], 200, function()
		ns.Confirm(L["Overwrite the FD macros you edited with ForeverDruid's version?"], function()
			ns.Print(L["restored"] .. " " .. ns.macros.Restore())
			b:Refresh()
		end)
	end, L["Puts ForeverDruid's text back into FD macros you changed. Asks first."])
	if ShowMacroFrame then
		b:Button(L["Open the macro window"], 200, function()
			ShowMacroFrame()
		end)
	end
	Finish(b)
	ns.Listen("FD_MACROS_CHANGED", function()
		if panel:IsVisible() then
			b:Refresh()
		end
	end)
	return panel
end

local function BuildPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		return
	end
	panelCategory = Settings.RegisterCanvasLayoutCategory(MainPage(), "ForeverDruid")
	Settings.RegisterAddOnCategory(panelCategory)
	if Settings.RegisterCanvasLayoutSubcategory then
		for _, key in ipairs(ns.moduleOrder) do
			local ok, err = pcall(function()
				local page = ModulePage(key)
				Settings.RegisterCanvasLayoutSubcategory(panelCategory, page, page.name)
			end)
			if not ok then
				ns.ReportError(err)
			end
		end
		local ok, err = pcall(function()
			local page = MacrosPage()
			ns.macrosCategory = Settings.RegisterCanvasLayoutSubcategory(panelCategory, page, page.name)
		end)
		if not ok then
			ns.ReportError(err)
		end
	end
end

ns.Listen("FD_LOGIN", function()
	local ok, err = pcall(BuildPanel)
	if not ok then
		ns.ReportError(err)
	end
end)
