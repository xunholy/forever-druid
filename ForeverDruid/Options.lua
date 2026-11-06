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
	ns.Print("  /fd toggle <module> - manabar, energytick, combopoints, cooldowns, buffs, targetauras, reminders")
	ns.Print("  /fd cd add|remove <role|all> <spell> - " .. L["track extra cooldowns"])
	ns.Print("  /fd cd list")
	ns.Print("  /fd profile [list | use <name> | copy <name> | reset | delete <name>]")
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

function ns.OpenOptions()
	if panelCategory and Settings and Settings.OpenToCategory then
		local id = panelCategory.GetID and panelCategory:GetID() or panelCategory.ID
		if id then
			Settings.OpenToCategory(id)
			return
		end
	end
	ns.Print(L["Open Options > AddOns > ForeverDruid."])
end

-- Layout helper: widgets stack top to bottom inside a scroll child.
local Builder = {}
Builder.__index = Builder

local sliderCount = 0

local function NewBuilder(content)
	return setmetatable({ content = content, y = -16, refreshers = {} }, Builder)
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
end

function Builder:Check(label, get, set, indent)
	local check = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", 16 + (indent or 0), self.y)
	local text = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetText(label)
	check:SetScript("OnClick", function(widget)
		set(widget:GetChecked() and true or false)
	end)
	self.refreshers[#self.refreshers + 1] = function()
		check:SetChecked(get() and true or false)
	end
	self.y = self.y - 28
	return check
end

function Builder:Slider(label, minValue, maxValue, step, get, set, indent)
	sliderCount = sliderCount + 1
	local name = "ForeverDruidOptionsSlider" .. sliderCount
	local slider = CreateFrame("Slider", name, self.content, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 24 + (indent or 0), self.y - 14)
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
	self.refreshers[#self.refreshers + 1] = function()
		local value = get()
		slider:SetValue(value)
		Label(value)
	end
	self.y = self.y - 46
	return slider
end

function Builder:Button(label, width, onClick)
	local button = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
	button:SetSize(width or 140, 22)
	button:SetPoint("TOPLEFT", 20, self.y)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	self.y = self.y - 28
	return button
end

function Builder:Cycle(label, values, get, set)
	local button = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
	button:SetSize(200, 22)
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
	self.refreshers[#self.refreshers + 1] = Render
	self.y = self.y - 28
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
	manabar = "Your mana while in Cat or Bear Form, with the cost of one shift marked.",
	energytick = "Learns Forever's energy ticks in Cat Form and sweeps a spark to the next one.",
	combopoints = "Five pips that turn red at five points.",
	cooldowns = "Cooldowns for what you're doing right now, limited to spells you know.",
	buffs = "Clearcasting, Tiger's Fury, Barkskin, Enrage and other buffs, with timers.",
	targetauras = "Your DoTs on an enemy target or your HoTs on a friendly one.",
	reminders = "Out of combat only. Click a buff reminder to cast it.",
}

local function ModuleSection(b, key, extra)
	b:Header(L[MODULE_TITLES[key]])
	b:Note(L[MODULE_NOTES[key]])
	b:Check(L["Enabled"], ModuleGetter(key, "enabled"), function(value)
		ns.SetModuleEnabled(key, value)
	end)
	b:Slider(L["Scale"], 0.5, 2, 0.05, ModuleGetter(key, "scale"), ModuleSetter(key, "scale", "scale"))
	if ns.IsStackable(key) then
		b:Check(L["Part of the stack"], function()
			return not ns.db.layout.detached[key]
		end, function(value)
			ns.SetStacked(key, value)
		end)
	end
	if extra then
		extra(b)
	end
end

local function BuildPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		return
	end
	local panel = CreateFrame("Frame")
	panel.name = "ForeverDruid"

	local scroll = CreateFrame("ScrollFrame", "ForeverDruidOptionsScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(600, 1)
	scroll:SetScrollChild(content)

	local b = NewBuilder(content)

	local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
	title:SetPoint("TOPLEFT", 16, b.y)
	title:SetText("ForeverDruid |cffffffff" .. ns.VERSION .. "|r")
	b.y = b.y - 34
	b:Note(L["A druid HUD for WoW Forever. Profile:"] .. " " .. tostring(ns.profileName) .. "  (/fd profile)")

	-- General
	b:Header(L["General"])
	b:Button(L["Unlock / lock"], 140, function()
		ns.SetUnlocked(not ns.db.unlocked)
	end)
	b:Button(L["Reset positions"], 140, function()
		ns.ResetPositions()
	end)
	b:Check(L["Stack the HUD automatically"], function()
		return ns.db.layout.stack
	end, function(value)
		ns.SetStackEnabled(value)
	end)
	b:Note(L["One column under your character that closes up when a piece is hidden. Drag any piece to move it all; shift-drag a piece to give it its own spot."])
	b:Slider(L["Space between stacked pieces"], 0, 20, 1, function()
		return ns.db.layout.gap
	end, function(value)
		ns.db.layout.gap = value
		ns.LayoutStack()
	end)
	b:Slider(L["Overall scale"], 0.5, 2, 0.05, function()
		return ns.db.scale
	end, function(value)
		ns.db.scale = value
		ns.ApplyScales()
	end)
	b:Slider(L["Opacity out of combat"], 0, 1, 0.05, function()
		return ns.db.fadeOutOfCombat
	end, function(value)
		ns.db.fadeOutOfCombat = value
		ns.UpdateVisibility()
	end)
	b:Check(L["Show the minimap button"], function()
		return not ns.db.minimap.hide
	end, function(value)
		if ns.SetMinimapButtonShown then
			ns.SetMinimapButtonShown(value)
		else
			ns.db.minimap.hide = not value
		end
	end)
	b:Check(L["Hide while mounted"], function()
		return ns.db.hideWhenMounted
	end, function(value)
		ns.db.hideWhenMounted = value
		ns.UpdateVisibility()
	end)

	ModuleSection(b, "manabar", function(s)
		s:Cycle(L["Text"], ns.modules.manabar.TEXT_MODES, ModuleGetter("manabar", "text"), ModuleSetter("manabar", "text"))
		s:Check(L["Colour by mana level"], ModuleGetter("manabar", "colorByLevel"), ModuleSetter("manabar", "colorByLevel"))
		s:Check(L["Mark the cost of one shift"], ModuleGetter("manabar", "shiftMarker"), ModuleSetter("manabar", "shiftMarker"))
		s:Check(L["Show in every form"], ModuleGetter("manabar", "alwaysShow"), ModuleSetter("manabar", "alwaysShow"))
		s:Slider(L["Width"], 80, 400, 5, ModuleGetter("manabar", "width"), ModuleSetter("manabar", "width"))
		s:Slider(L["Height"], 4, 30, 1, ModuleGetter("manabar", "height"), ModuleSetter("manabar", "height"))
	end)
	ModuleSection(b, "energytick", function(s)
		s:Slider(L["Width"], 80, 400, 5, ModuleGetter("energytick", "width"), ModuleSetter("energytick", "width"))
		s:Slider(L["Height"], 2, 20, 1, ModuleGetter("energytick", "height"), ModuleSetter("energytick", "height"))
	end)
	ModuleSection(b, "combopoints", function(s)
		s:Check(L["Only in Cat Form"], ModuleGetter("combopoints", "catOnly"), ModuleSetter("combopoints", "catOnly"))
		s:Slider(L["Pip size"], 6, 30, 1, ModuleGetter("combopoints", "size"), ModuleSetter("combopoints", "size"))
	end)
	ModuleSection(b, "cooldowns", function(s)
		s:Check(L["Countdown numbers"], ModuleGetter("cooldowns", "showNumbers"), ModuleSetter("cooldowns", "showNumbers"))
		s:Check(L["Tooltips on mouseover"], ModuleGetter("cooldowns", "tooltips"), ModuleSetter("cooldowns", "tooltips"))
		s:Check(L["Include Skyborne racials"], ModuleGetter("cooldowns", "racials"), ModuleSetter("cooldowns", "racials"))
		s:Check(L["Hide out of combat"], ModuleGetter("cooldowns", "hideOutOfCombat"), ModuleSetter("cooldowns", "hideOutOfCombat"))
		s:Slider(L["Icon size"], 16, 64, 1, ModuleGetter("cooldowns", "size"), ModuleSetter("cooldowns", "size"))
		s:Note(L["Add your own: /fd cd add <role|all> <spell name>"])
	end)
	ModuleSection(b, "buffs", function(s)
		s:Slider(L["Icon size"], 16, 64, 1, ModuleGetter("buffs", "size"), ModuleSetter("buffs", "size"))
	end)
	ModuleSection(b, "targetauras", function(s)
		s:Slider(L["Icon size"], 16, 64, 1, ModuleGetter("targetauras", "size"), ModuleSetter("targetauras", "size"))
		s:Slider(L["Most shown"], 1, 16, 1, ModuleGetter("targetauras", "max"), ModuleSetter("targetauras", "max"))
	end)
	ModuleSection(b, "reminders", function(s)
		s:Check(L["Click a reminder to cast it"], ModuleGetter("reminders", "clickToCast"), ModuleSetter("reminders", "clickToCast"))
		s:Check(L["Mark of the Wild"], ModuleGetter("reminders", "markOfTheWild"), ModuleSetter("reminders", "markOfTheWild"))
		s:Check(L["Omen of Clarity (only where it's a castable buff)"], ModuleGetter("reminders", "omenOfClarity"), ModuleSetter("reminders", "omenOfClarity"))
		s:Check(L["Thorns (always)"], ModuleGetter("reminders", "thorns"), ModuleSetter("reminders", "thorns"))
		s:Check(L["Thorns in Bear Form"], ModuleGetter("reminders", "thornsInBear"), ModuleSetter("reminders", "thornsInBear"))
		s:Check(L["Low Rebirth / Gift of the Wild reagents"], ModuleGetter("reminders", "reagents"), ModuleSetter("reminders", "reagents"))
		s:Check(L["Skyborne: not attuned to a ley line"], ModuleGetter("reminders", "attuned"), ModuleSetter("reminders", "attuned"))
	end)

	b:Header(L["Diagnostics"])
	b:Check(L["Record probe snapshots automatically"], function()
		return ns.db.probe.auto
	end, function(value)
		ns.db.probe.auto = value
	end)
	b:Button(L["Take a snapshot now"], 180, function()
		ns.PrintSnapshot(ns.TakeSnapshot("manual"))
	end)

	content:SetHeight(-b.y + 20)
	panel:SetScript("OnShow", function()
		b:Refresh()
	end)

	panelCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(panelCategory)
end

ns.Listen("FD_LOGIN", function()
	local ok, err = pcall(BuildPanel)
	if not ok then
		ns.ReportError(err)
	end
end)
