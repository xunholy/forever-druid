-- A druid icon on the minimap ring with a quick settings menu.
--   Left-click: quick menu (what's shown, size, fading, layout, reminders, profiles)
--   Right-click: unlock / lock the HUD for moving
--   Shift-click: the full options panel
--   Drag: move the icon around the ring
-- The addon menu entry (minimap addon compartment) opens the same quick menu.

local _, ns = ...
local L = ns.L

local button
local atan2 = math.atan2 or math.atan -- WoW's Lua 5.1 has atan2; 5.3+ folds it into atan

---------------------------------------------------------------------------
-- Quick menu
---------------------------------------------------------------------------

local function Refresh(key)
	local module = ns.modules[key]
	if module and module.enabled and module.Refresh then
		local ok, err = pcall(module.Refresh, module)
		if not ok then
			ns.ReportError(err)
		end
	end
end

local function ModuleOption(key, field)
	return function()
		return ns.db.modules[key][field]
	end, function()
		ns.db.modules[key][field] = not ns.db.modules[key][field]
		Refresh(key)
	end
end

local function Percent(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local SIZES = { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }
local FADES = { { 1, "Fully visible" }, { 0.6, "Faded" }, { 0.3, "Faint" }, { 0, "Hidden" } }
local THORNS = {
	{ "never", "Never", false, false },
	{ "bear", "In Bear Form", false, true },
	{ "always", "Always", true, true },
}

local function ThornsMode()
	local cfg = ns.db.modules.reminders
	if cfg.thorns then
		return "always"
	end
	return cfg.thornsInBear and "bear" or "never"
end

-- Builds the menu into a rootDescription from Blizzard's Menu system. Kept separate from the
-- opening code so the tests can walk it.
function ns.BuildQuickMenu(root)
	root:CreateTitle("ForeverDruid " .. ns.VERSION)

	root:CreateCheckbox(L["Unlock to move"], function()
		return ns.db.unlocked
	end, function()
		ns.SetUnlocked(not ns.db.unlocked)
	end)
	root:CreateCheckbox(L["Stack automatically"], function()
		return ns.db.layout.stack
	end, function()
		ns.SetStackEnabled(not ns.db.layout.stack)
	end)
	local arrange = root:CreateButton(L["While unlocked"])
	arrange:CreateCheckbox(L["Sample icons"], function()
		return ns.db.preview
	end, function()
		ns.db.preview = not ns.db.preview
		ns.Fire("FD_LOCK_CHANGED", ns.db.unlocked)
	end)
	arrange:CreateCheckbox(L["Alignment grid"], function()
		return ns.db.grid
	end, function()
		ns.db.grid = not ns.db.grid
		ns.UpdateGrid()
	end)

	local show = root:CreateButton(L["Show"])
	for _, key in ipairs(ns.moduleOrder) do
		show:CreateCheckbox(L[ns.MODULE_TITLES[key] or key], function()
			return ns.db.modules[key].enabled
		end, function()
			ns.SetModuleEnabled(key, not ns.db.modules[key].enabled)
		end)
	end

	local size = root:CreateButton(L["HUD size"])
	for _, value in ipairs(SIZES) do
		size:CreateRadio(Percent(value), function()
			return math.abs((ns.db.scale or 1) - value) < 0.001
		end, function()
			ns.db.scale = value
			ns.ApplyScales()
		end)
	end

	local look = root:CreateButton(L["Icon style"])
	for _, style in ipairs(ns.ICON_STYLES) do
		look:CreateRadio(L[style], function()
			return ns.db.style.icons == style
		end, function()
			ns.db.style.icons = style
			ns.RestyleAll()
		end)
	end

	local fade = root:CreateButton(L["Out of combat"])
	for _, option in ipairs(FADES) do
		fade:CreateRadio(L[option[2]], function()
			return math.abs((ns.db.fadeOutOfCombat or 1) - option[1]) < 0.001
		end, function()
			ns.db.fadeOutOfCombat = option[1]
			ns.UpdateVisibility()
		end)
	end
	fade:CreateCheckbox(L["Hide while mounted"], function()
		return ns.db.hideWhenMounted
	end, function()
		ns.db.hideWhenMounted = not ns.db.hideWhenMounted
		ns.UpdateVisibility()
		Refresh("reminders")
	end)
	fade:CreateCheckbox(L["Hide cooldowns out of combat"], ModuleOption("cooldowns", "hideOutOfCombat"))

	local forms = root:CreateButton(L["Forms"])
	forms:CreateCheckbox(L["Mana bar in every form"], ModuleOption("manabar", "alwaysShow"))
	forms:CreateCheckbox(L["Combo points only in Cat Form"], ModuleOption("combopoints", "catOnly"))
	local text = forms:CreateButton(L["Mana bar text"])
	for _, mode in ipairs(ns.modules.manabar.TEXT_MODES or {}) do
		text:CreateRadio(L[mode], function()
			return ns.db.modules.manabar.text == mode
		end, function()
			ns.db.modules.manabar.text = mode
			Refresh("manabar")
		end)
	end

	local reminders = root:CreateButton(L["Reminders"])
	reminders:CreateCheckbox(L["Click a reminder to cast it"], ModuleOption("reminders", "clickToCast"))
	reminders:CreateCheckbox(L["Mark of the Wild"], ModuleOption("reminders", "markOfTheWild"))
	local thorns = reminders:CreateButton(L["Thorns"])
	for _, option in ipairs(THORNS) do
		thorns:CreateRadio(L[option[2]], function()
			return ThornsMode() == option[1]
		end, function()
			ns.db.modules.reminders.thorns = option[3]
			ns.db.modules.reminders.thornsInBear = option[4]
			Refresh("reminders")
		end)
	end
	reminders:CreateCheckbox(L["Low reagents"], ModuleOption("reminders", "reagents"))
	reminders:CreateCheckbox(L["Ley line (Skyborne)"], ModuleOption("reminders", "attuned"))
	reminders:CreateCheckbox(L["Trainer visit after levelling up"], ModuleOption("reminders", "trainer"))
	reminders:CreateCheckbox(L["Bear and Cat Form class quests"], ModuleOption("reminders", "formQuests"))
	reminders:CreateCheckbox(L["Restock reagents at vendors"], function()
		return ns.db.restock.enabled
	end, function()
		ns.db.restock.enabled = not ns.db.restock.enabled
	end)

	local role = root:CreateButton(L["Caster-form role"] .. ": " .. L[ns.db.role])
	for _, value in ipairs(ns.CASTER_ROLES) do
		role:CreateRadio(L[value], function()
			return ns.db.role == value
		end, function()
			ns.db.role = value
			ns.UpdateRole()
		end)
	end
	root:CreateCheckbox(L["Highest ranks on my action bars"], function()
		return ns.db.ranks.auto
	end, function()
		ns.db.ranks.auto = not ns.db.ranks.auto
		if ns.db.ranks.auto then
			ns.ranks.Upgrade()
		end
	end)
	local macros = root:CreateButton(L["Macros"])
	macros:CreateCheckbox(L["Create and update my druid macros"], function()
		return ns.db.macros.manage
	end, function()
		ns.macros.SetManaged(not ns.db.macros.manage)
	end)
	if ns.db.macros.manage then
		macros:CreateDivider()
		for _, def in ipairs(ns.macros.LIST) do
			local _, state = ns.MacroStatusText(def.key)
			if state == "ready" or state == "edited" then
				-- Click to put it on the cursor, then click an action bar slot.
				macros:CreateButton(L["Pick up"] .. ": " .. def.name, function()
					ns.macros.PickUp(def.key)
				end)
			end
		end
	end
	macros:CreateButton(L["Macro settings..."], function()
		ns.OpenOptions(ns.macrosCategory)
	end)

	local profiles = root:CreateButton(L["Profile"] .. ": " .. tostring(ns.profileName))
	for _, name in ipairs(ns.ProfileNames()) do
		profiles:CreateRadio(name, function()
			return (ns.global.chars[ns.charKey] or ns.profileName) == name
		end, function()
			ns.UseProfile(name)
			if name ~= ns.profileName then
				ns.Print(L["switched to profile"] .. " " .. name .. " - /reload " .. L["to apply"])
			end
		end)
	end
	profiles:CreateButton(L["Share this profile..."], function()
		ns.ShowShareWindow("export")
	end)
	profiles:CreateButton(L["Import a profile..."], function()
		ns.ShowShareWindow("import")
	end)
	if ReloadUI then
		profiles:CreateButton(L["Reload now"], function()
			ReloadUI()
		end)
	end

	root:CreateDivider()
	root:CreateButton(L["Reset positions"], function()
		ns.ConfirmResetPositions()
	end)
	root:CreateButton(L["All settings..."], function()
		ns.OpenOptions()
	end)
	root:CreateButton(L["Hide this minimap button"], function()
		ns.SetMinimapButtonShown(false)
		ns.Print(L["minimap button hidden - /fd minimap brings it back"])
	end)
end

function ns.OpenQuickMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		ns.OpenOptions()
		return
	end
	MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
		local ok, err = pcall(ns.BuildQuickMenu, root)
		if not ok then
			ns.ReportError(err)
		end
	end)
end

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------

-- Where on the ring an angle (degrees, 0 = right, counter-clockwise) puts the button.
-- Round minimaps get a circle; square ones (set by some map addons) get the square's edge.
function ns.MinimapOffset(angle)
	local radians = math.rad(angle)
	local x, y = math.cos(radians), math.sin(radians)
	local w = (tonumber(Minimap:GetWidth()) or 140) / 2 + 5
	local h = (tonumber(Minimap:GetHeight()) or 140) / 2 + 5
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	if shape == "SQUARE" then
		local diagW, diagH = math.sqrt(2 * w * w) - 10, math.sqrt(2 * h * h) - 10
		return math.max(-w, math.min(x * diagW, w)), math.max(-h, math.min(y * diagH, h))
	end
	return x * w, y * h
end

local function Place()
	local x, y = ns.MinimapOffset(ns.db.minimap.angle or 200)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CursorAngle()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	if not (mx and my and px and py and scale) then
		return nil
	end
	return math.deg(atan2(py / scale - my, px / scale - mx)) % 360
end

local function ShowTooltip(owner)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:SetText("ForeverDruid " .. ns.VERSION)
	GameTooltip:AddLine(L["Left-click: quick settings"], 1, 1, 1)
	GameTooltip:AddLine(L["Right-click: unlock / lock to move the HUD"], 1, 1, 1)
	GameTooltip:AddLine(L["Shift-click: all settings"], 1, 1, 1)
	GameTooltip:AddLine(L["Drag: move this button"], 0.7, 0.7, 0.7)
	GameTooltip:Show()
end
ns.ShowLauncherTooltip = ShowTooltip

-- Shared by the minimap button and the addon menu entry.
function ns.LauncherClick(owner, mouseButton)
	if mouseButton == "RightButton" then
		if ns.SetUnlocked(not ns.db.unlocked) then
			ns.Print(ns.db.unlocked and L["unlocked: drag any green box to move the whole HUD, shift-drag one to give it its own spot, then /fd lock"] or L["locked"])
		end
	elseif IsShiftKeyDown and IsShiftKeyDown() then
		ns.OpenOptions()
	else
		ns.OpenQuickMenu(owner)
	end
end

local function CreateButton()
	button = CreateFrame("Button", "ForeverDruidMinimapButton", Minimap)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetSize(31, 31)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture("Interface\\Icons\\Ability_Druid_CatForm")
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(self, mouseButton)
		ns.LauncherClick(self, mouseButton)
	end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		if GameTooltip then
			GameTooltip:Hide()
		end
		self:SetScript("OnUpdate", function()
			local angle = CursorAngle()
			if angle then
				ns.db.minimap.angle = angle
				Place()
			end
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	ns.minimapButton = button
end

function ns.SetMinimapButtonShown(shown)
	ns.db.minimap.hide = not shown
	if shown and not button and Minimap then
		CreateButton()
	end
	if button then
		Place()
		button:SetShown(shown)
	end
end

ns.Listen("FD_LOGIN", function()
	-- Other classes keep only /fd probe; no icon cluttering their minimap.
	if not ns.isDruid or not Minimap then
		return
	end
	local ok, err = pcall(ns.SetMinimapButtonShown, not ns.db.minimap.hide)
	if not ok then
		ns.ReportError(err)
	end
end)
