-- Click-to-heal party frames: you and your party as clickable bars. Left-click, right-click, middle
-- and shift-clicks cast the spells you choose on that person, with their health, your HoTs and an
-- out-of-range shade.
--
-- The buttons come from Blizzard's SecureGroupHeaderTemplate, so they keep working in combat and
-- when people join mid-fight: the header copies the click setup onto every new button itself.
-- Settings can only be changed out of combat (secure frames can't be). The bars, names and HoT
-- icons are drawn by the addon out of combat; a member who joins mid-fight gets a working button
-- straight away and its drawings when the fight ends. Health and range are hidden values, handed
-- straight to the bar and a shade so the client draws them.

local _, ns = ...

local M = ns.RegisterModule("healframes", {})

M.CLICKS = {
	{ key = "left", button = "1", label = "Left-click", target = true },
	{ key = "right", button = "2", label = "Right-click", target = true },
	{ key = "middle", button = "3", label = "Middle-click" },
	{ key = "shiftLeft", button = "1", modifier = "shift-", label = "Shift + left-click" },
	{ key = "shiftRight", button = "2", modifier = "shift-", label = "Shift + right-click" },
}
-- What a click can do: a spell key, "target" (left and right click only: only they have the game's
-- default targeting binding) or "none". Only spells you know are applied.
M.ACTIONS = { "rejuvenation", "regrowth", "healingTouch", "removeCurse", "abolishPoison", "curePoison",
	"innervate", "rebirth", "markOfTheWild", "thorns", "none" }
M.TARGET_ACTIONS = { "target", "rejuvenation", "regrowth", "healingTouch", "removeCurse", "abolishPoison", "curePoison",
	"innervate", "rebirth", "markOfTheWild", "thorns", "none" }

M.stats = { configured = 0, decorated = 0, deferred = 0 }
local header
local decorated = setmetatable({}, { __mode = "k" })
local pending = false
local MODIFIERS = { "", "shift-", "ctrl-", "alt-" }
local NOOP = ATTRIBUTE_NOOP or ""

-- type and spell values for one action.
local function TypeAndSpell(action, allowTarget)
	if action == "target" and allowTarget then
		return "target", nil
	end
	local name = action and action ~= "none" and action ~= "target" and ns.IsCastable(action) and ns.SpellName(action)
	if name then
		return "spell", name
	end
	return NOOP, nil
end
M.TypeAndSpell = TypeAndSpell

-- Every attribute the click setup needs, with no wildcards: each button (1-3) with no modifier,
-- shift, ctrl and alt gets its own explicit entry, so a click set to "none" really does nothing
-- instead of falling through to another click's spell.
function M.Attributes()
	local cfg = ns.ModuleConfig("healframes")
	local chosen = {} -- [modifier .. button] = click
	for _, click in ipairs(M.CLICKS) do
		chosen[(click.modifier or "") .. click.button] = click
	end
	local list = {}
	for _, buttonNumber in ipairs({ "1", "2", "3" }) do
		for _, modifier in ipairs(MODIFIERS) do
			local click = chosen[modifier .. buttonNumber]
			local action = click and (cfg.clicks[click.key] or "none") or "none"
			local kind, spell = TypeAndSpell(action, click and click.target)
			list[#list + 1] = { modifier .. "type" .. buttonNumber, kind }
			list[#list + 1] = { modifier .. "spell" .. buttonNumber, spell }
		end
	end
	return list
end

local function Children()
	local out = {}
	if not header then
		return out
	end
	for i = 1, 5 do
		local child = rawget(header, i)
		if child then
			out[#out + 1] = child
		end
	end
	return out
end

-- Applies the click setup to the header (for buttons it creates later) and to every existing
-- button, and registers right/middle clicks (a protected call). Out of combat only.
function M.Configure()
	if not header then
		return false
	end
	if InCombatLockdown() then
		pending = true
		M.stats.deferred = M.stats.deferred + 1
		return false
	end
	local names = {}
	for _, pair in ipairs(M.Attributes()) do
		local attr, value = pair[1], pair[2]
		names[#names + 1] = attr
		header:SetAttribute("_initialAttribute-" .. attr, value)
		for _, child in ipairs(Children()) do
			child:SetAttribute(attr, value)
		end
	end
	header:SetAttribute("_initialAttributeNames", table.concat(names, ","))
	for _, child in ipairs(Children()) do
		child:RegisterForClicks("AnyUp")
	end
	M.stats.configured = M.stats.configured + 1
	return true
end

---------------------------------------------------------------------------
-- Drawing on the buttons (insecure child frames; created out of combat only)
---------------------------------------------------------------------------

local function Decorate(button)
	if decorated[button] or InCombatLockdown() then
		return decorated[button]
	end
	local cfg = ns.ModuleConfig("healframes")
	local d = {}
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)
	local bar = CreateFrame("StatusBar", nil, button)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", -1, 1)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.15, 0.75, 0.25)
	bar:SetMinMaxValues(0, 1)
	bar:EnableMouse(false)
	d.bar = bar
	local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	name:SetPoint("LEFT", bar, "LEFT", 4, 0)
	name:SetWidth(cfg.width - 60)
	name:SetJustifyH("LEFT")
	d.name = name
	d.hots = {}
	for i = 1, 3 do
		local icon = ns.CreateIcon(bar, cfg.height - 6, { reverse = true })
		icon:SetPoint("RIGHT", bar, "RIGHT", -2 - (i - 1) * (cfg.height - 4), 0)
		icon:EnableMouse(false)
		icon:SetAlpha(0)
		d.hots[i] = icon
	end
	-- Out of range: a dark shade driven by the client's own (hidden) range check.
	local shade = bar:CreateTexture(nil, "OVERLAY", nil, 7)
	shade:SetAllPoints()
	shade:SetColorTexture(1, 1, 1, 1)
	shade:SetVertexColor(0, 0, 0, 0)
	d.shade = shade
	decorated[button] = d
	M.stats.decorated = M.stats.decorated + 1
	return d
end

local colors
local function Colors()
	if not colors and CreateColor then
		colors = { clear = CreateColor(0, 0, 0, 0), dim = CreateColor(0, 0, 0, 0.55) }
	end
	return colors
end

local function Paint(button)
	local d = Decorate(button)
	if not d then
		return
	end
	local unit = button:GetAttribute("unit")
	if not unit or not ns.SafeReadable(UnitExists, unit) then
		return
	end
	d.name:SetText(UnitName(unit))
	if UnitHealthPercent then
		local ok, value = pcall(UnitHealthPercent, unit, true)
		if ok then
			d.bar:SetValue(value)
		end
	end
	local hots = ns.modules.party and ns.modules.party.HotsOn and ns.modules.party.HotsOn(unit) or {}
	for i, icon in ipairs(d.hots) do
		local aura = hots[i]
		if aura then
			pcall(function()
				icon.icon:SetTexture(aura.icon)
				icon.cooldown:SetCooldownFromExpirationTime(aura.expirationTime, aura.duration)
			end)
			icon:SetAlpha(1)
		else
			icon:SetAlpha(0)
		end
	end
	local c = Colors()
	if c and UnitInRange and d.shade.SetVertexColorFromBoolean and unit ~= "player" then
		local ok, inRange = pcall(UnitInRange, unit)
		if ok and (ns.IsSecret(inRange) or inRange ~= nil) then
			d.shade:SetVertexColorFromBoolean(inRange, c.clear, c.dim)
		end
	else
		d.shade:SetVertexColor(0, 0, 0, 0)
	end
end

function M:Paint()
	for _, child in ipairs(Children()) do
		local ok, err = pcall(Paint, child)
		if not ok then
			ns.ReportError(err)
		end
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function CreateHeader()
	local cfg = ns.ModuleConfig("healframes")
	header = CreateFrame("Frame", "ForeverDruidHealHeader", UIParent, "SecureGroupHeaderTemplate")
	header:SetAttribute("showParty", true)
	header:SetAttribute("showPlayer", true)
	header:SetAttribute("showSolo", cfg.showSolo and true or false)
	header:SetAttribute("showRaid", false)
	header:SetAttribute("point", "TOP")
	header:SetAttribute("yOffset", -3)
	header:SetAttribute("template", "SecureUnitButtonTemplate")
	header:SetAttribute("templateType", "Button")
	header:SetAttribute("unitsPerColumn", 5)
	-- Runs in Blizzard's secure environment for each new button. (Clicks are registered from
	-- Configure: RegisterForClicks isn't available there.)
	header:SetAttribute("initialConfigFunction", ([[
		self:SetWidth(%d)
		self:SetHeight(%d)
	]]):format(cfg.width, cfg.height))
	local saved = ns.db.positions.healframes
	header:ClearAllPoints()
	if saved then
		header:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
	else
		header:SetPoint("TOPLEFT", UIParent, "CENTER", -460, 120)
	end
	header:SetMovable(true)
	header:SetClampedToScreen(true)
	M.header = header
end

function M:Init()
	if InCombatLockdown() then
		-- Secure frames can't be created mid-fight; build them as it ends.
		self.initPending = true
		return
	end
	CreateHeader()
	self.anchor = header
	ns.On("GROUP_ROSTER_UPDATE", function()
		if self.enabled and not InCombatLockdown() then
			self:Paint()
		end
	end)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if pending then
			self:Apply() -- replay whatever was asked for during the fight
		elseif self.enabled then
			self:Paint()
		end
	end)
	ns.Listen("FD_SPELLS_CHANGED", function()
		if self.enabled then
			M.Configure()
		end
	end)
	C_Timer.NewTicker(0.25, function()
		if self.enabled and header:IsVisible() then
			self:Paint()
		end
	end)
end

-- Brings the frames in line with the settings: shown or hidden, solo option, click setup. Out of
-- combat only; asked for in combat, it runs as the fight ends.
function M:Apply()
	if InCombatLockdown() then
		pending = true
		return false
	end
	pending = false
	if not self.enabled then
		if header then
			header:Hide()
		end
		return true
	end
	if not header then
		CreateHeader()
		self.anchor = header
	end
	header:SetAttribute("showSolo", ns.ModuleConfig("healframes").showSolo and true or false)
	-- Make all five buttons now, out of combat (the usual group-frame trick: a negative starting
	-- index), so their clicks can be registered before anyone joins mid-fight.
	header:SetAttribute("startingIndex", -4)
	header:Show()
	header:SetAttribute("startingIndex", 1)
	M.Configure()
	self:Paint()
	return true
end

function M:Refresh()
	self:Apply()
end

function M:Enable()
	if not header and not InCombatLockdown() then
		self:Init()
	end
	self:Apply()
end

function M:Disable()
	self:Apply()
end

-- Logged in mid-fight: build the frames as soon as it ends.
ns.On("PLAYER_REGEN_ENABLED", function()
	if M.enabled and not header then
		M:Init()
		M:Apply()
	end
end)

-- Moving: drag isn't safe on a secure header in combat; nudge or move it from settings instead.
function M.Move(dx, dy)
	if not header or InCombatLockdown() then
		return false
	end
	local point, _, relativePoint, x, y = header:GetPoint(1)
	header:ClearAllPoints()
	header:SetPoint(point, UIParent, relativePoint, (x or 0) + dx, (y or 0) + dy)
	ns.db.positions.healframes = { point, relativePoint, (x or 0) + dx, (y or 0) + dy }
	return true
end
