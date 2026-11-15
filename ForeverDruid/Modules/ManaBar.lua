-- Mana bars shown while in Cat or Bear Form, where the player frame only shows energy or rage.
-- There are two, switched on separately: one in the HUD column, and one attached under the player
-- frame's own power bar, the way the game does it in versions that have a second power bar.
--
-- Forever keeps the player's mana secret at all times, so nothing here does maths on it:
--   * the bar and "current / max" text take the raw values;
--   * percentage text and the low-mana colour come from UnitPowerPercent evaluated against a curve,
--     which the client computes without exposing the number;
--   * the powershift marker uses the form's mana cost and maximum mana, both of which are readable.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("manabar", {})

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local SHAPESHIFTED = { cat = true, bear = true }
local FORM_SPELL = { cat = { "catForm" }, bear = { "direBearForm", "bearForm" } }
local BASE_COLOR = { 0.10, 0.40, 1.00 }

M.TEXT_MODES = { "value", "percent", "both", "none" }

local function BuildCurves()
	local curveUtil = C_CurveUtil
	if not curveUtil then
		return
	end
	local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear
	if curveUtil.CreateCurve then
		local ok, curve = pcall(curveUtil.CreateCurve)
		if ok and curve then
			if linear and curve.SetType then
				curve:SetType(linear)
			end
			curve:AddPoint(0.0, 0)
			curve:AddPoint(1.0, 100)
			M.percentCurve = curve
		end
	end
	if curveUtil.CreateColorCurve and CreateColor then
		local ok, curve = pcall(curveUtil.CreateColorCurve)
		if ok and curve then
			if linear and curve.SetType then
				curve:SetType(linear)
			end
			curve:AddPoint(0.00, CreateColor(0.85, 0.15, 0.15))
			curve:AddPoint(0.25, CreateColor(0.95, 0.55, 0.10))
			curve:AddPoint(0.50, CreateColor(BASE_COLOR[1], BASE_COLOR[2], BASE_COLOR[3]))
			curve:AddPoint(1.00, CreateColor(BASE_COLOR[1], BASE_COLOR[2], BASE_COLOR[3]))
			M.colorCurve = curve
		end
	end
end

-- Mana percentage evaluated through a curve. Returns ok, result; the result is usually secret, so
-- callers branch on `ok` only and never compare or test the result itself.
local function PercentThrough(curve)
	if not (curve and UnitPowerPercent) then
		return false
	end
	return pcall(UnitPowerPercent, "player", MANA, false, curve)
end

-- A mana bar: status bar, text and the powershift marker, filling `parent`.
local function NewBar(parent, font)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetAllPoints()
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(BASE_COLOR[1], BASE_COLOR[2], BASE_COLOR[3])
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)

	local marker = bar:CreateTexture(nil, "OVERLAY")
	marker:SetColorTexture(1, 1, 1, 0.9)
	marker:SetWidth(2)
	marker:Hide()

	local text = bar:CreateFontString(nil, "OVERLAY", font)
	text:SetPoint("CENTER")
	bar:Hide()
	return { frame = parent, bar = bar, text = text, marker = marker }
end

-- The player frame's own power bar (energy or rage in a form), or nil if another addon replaced
-- the frame. Only read, to anchor under it.
local function PlayerPowerBar()
	local ok, bar = pcall(function()
		if PlayerFrame_GetManaBar then
			return PlayerFrame_GetManaBar()
		end
		return PlayerFrameManaBar
	end)
	if ok and type(bar) == "table" and bar.GetObjectType then
		return bar
	end
	return nil
end
M.PlayerPowerBar = PlayerPowerBar

function M:Init()
	local cfg = ns.ModuleConfig("manabar")
	BuildCurves()
	local anchor = ns.CreateAnchor("manabar", cfg.width, cfg.height, { "CENTER", "CENTER", 0, -170 }, L["Mana bar"], { fade = true })
	self.anchor = anchor
	self.hud = NewBar(anchor, "GameFontHighlightSmall")
	self.bar, self.text, self.marker = self.hud.bar, self.hud.text, self.hud.marker

	-- The attached bar is its own frame on UIParent, anchored to the player frame's power bar, so
	-- it follows that frame when it's moved or scaled and never becomes part of it.
	local holder = CreateFrame("Frame", "ForeverDruid_manabarAttached", UIParent)
	holder:Hide()
	self.attached = NewBar(holder, "GameFontHighlightSmall")
	holder:SetScript("OnSizeChanged", function()
		if self.enabled and holder:IsShown() then
			self:UpdateMarker(self.attached)
		end
	end)

	ns.OnUnit("UNIT_POWER_FREQUENT", "player", function(_, _, powerType)
		if self.enabled and powerType == "MANA" then
			self:Update()
		end
	end)
	ns.OnUnit("UNIT_MAXPOWER", "player", function()
		if self.enabled then
			self:Refresh()
		end
	end)
	local function Refresh()
		if self.enabled then
			self:Refresh()
		end
	end
	ns.Listen("FD_FORM_CHANGED", Refresh)
	ns.Listen("FD_LOCK_CHANGED", Refresh)
	ns.Listen("FD_SPELLS_CHANGED", Refresh)
end

function M:ShouldShow()
	local cfg = ns.ModuleConfig("manabar")
	return cfg.alwaysShow or SHAPESHIFTED[ns.form] or ns.db.unlocked
end

-- The attached bar only makes sense in a form: in caster form the frame above it already shows mana.
function M:ShouldShowAttached()
	local cfg = ns.ModuleConfig("manabar")
	return cfg.attach and (SHAPESHIFTED[ns.form] or ns.db.unlocked) and PlayerPowerBar() ~= nil
end

-- Fraction of maximum mana one shift into the current form costs, or nil.
function M.ShiftCostFraction(form)
	local keys = FORM_SPELL[form]
	if not (keys and C_Spell and C_Spell.GetSpellPowerCost) then
		return nil
	end
	local maximum = ns.SafeReadable(UnitPowerMax, "player", MANA)
	if not maximum or maximum <= 0 then
		return nil
	end
	for _, key in ipairs(keys) do
		local spellID = ns.KnownSpell(key)
		if spellID then
			local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
			if ok and type(costs) == "table" and not ns.IsSecret(costs) then
				for _, cost in ipairs(costs) do
					local kind, amount = ns.Readable(cost.type), ns.Readable(cost.cost)
					if kind == MANA and amount and amount > 0 then
						return math.min(1, amount / maximum)
					end
				end
			end
		end
	end
	return nil
end

function M:UpdateMarker(view)
	local cfg = ns.ModuleConfig("manabar")
	local fraction = cfg.shiftMarker and M.ShiftCostFraction(ns.form)
	local width = view == self.hud and cfg.width or view.frame:GetWidth()
	if fraction and type(width) == "number" and width > 0 then
		view.marker:ClearAllPoints()
		view.marker:SetPoint("TOP", view.bar, "TOPLEFT", fraction * width, 0)
		view.marker:SetPoint("BOTTOM", view.bar, "BOTTOMLEFT", fraction * width, 0)
		view.marker:Show()
	else
		view.marker:Hide()
	end
end

function M:UpdateColor(view)
	local cfg = ns.ModuleConfig("manabar")
	if cfg.colorByLevel then
		local ok, color = PercentThrough(M.colorCurve)
		-- The color object itself is a plain table whose r/g/b may be secret; only a secret
		-- object (or a failed call) forces the fallback color.
		if ok and not ns.IsSecret(color) and type(color) == "table" and color.GetRGB then
			local applied = pcall(function()
				view.bar:SetStatusBarColor(color:GetRGB())
			end)
			if applied then
				return
			end
		end
	end
	view.bar:SetStatusBarColor(BASE_COLOR[1], BASE_COLOR[2], BASE_COLOR[3])
end

function M:UpdateText(view)
	local cfg = ns.ModuleConfig("manabar")
	local mode = cfg.text
	if mode == "none" then
		view.text:SetText("")
		return
	end
	local current = UnitPower("player", MANA)
	local maximum = UnitPowerMax("player", MANA)
	local hasPercent, percent = false, nil
	if mode == "percent" or mode == "both" then
		hasPercent, percent = PercentThrough(M.percentCurve)
	end
	if mode == "percent" and hasPercent then
		view.text:SetFormattedText("%.0f%%", percent)
	elseif mode == "both" and hasPercent then
		view.text:SetFormattedText("%d  (%.0f%%)", current, percent)
	else
		-- Works for secret values too: the client formats them without exposing them to Lua.
		view.text:SetFormattedText("%d / %d", current, maximum)
	end
end

local function UpdateView(self, view)
	view.bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
	-- Smooth: the client eases the bar toward the new value (works with the secret value).
	local smooth = ns.ModuleConfig("manabar").smooth and Enum and Enum.StatusBarInterpolation
	if smooth then
		view.bar:SetValue(UnitPower("player", MANA), smooth.ExponentialEaseOut)
	else
		view.bar:SetValue(UnitPower("player", MANA))
	end
	self:UpdateColor(view)
	self:UpdateText(view)
end

function M:Update()
	for _, view in ipairs({ self.hud, self.attached }) do
		if view.bar:IsShown() then
			UpdateView(self, view)
		end
	end
end

-- Under the player frame's power bar, the same width, following it wherever it goes.
function M:PlaceAttached()
	local cfg = ns.ModuleConfig("manabar")
	local power = PlayerPowerBar()
	local holder = self.attached.frame
	if not power then
		return false
	end
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, cfg.attachOffset or 0)
	holder:SetPoint("TOPRIGHT", power, "BOTTOMRIGHT", 0, cfg.attachOffset or 0)
	holder:SetHeight(cfg.attachHeight or 9)
	return true
end

function M:Refresh()
	local cfg = ns.ModuleConfig("manabar")
	self.anchor:SetSize(cfg.width, cfg.height)
	-- Hide the whole row, not just the bar, so the stack closes up in caster form.
	local show = cfg.hud ~= false and self:ShouldShow() and true or false
	self.anchor:SetShown(show)
	self.hud.bar:SetShown(show)
	local attach = self:ShouldShowAttached() and self:PlaceAttached() and true or false
	self.attached.frame:SetShown(attach)
	self.attached.bar:SetShown(attach)
	for _, view in ipairs({ self.hud, self.attached }) do
		if view.bar:IsShown() then
			UpdateView(self, view)
			self:UpdateMarker(view)
		end
	end
end

function M:Enable()
	self.anchor:Show()
	self:Refresh()
end

function M:Disable()
	self.hud.bar:Hide()
	self.anchor:Hide()
	self.attached.bar:Hide()
	self.attached.frame:Hide()
end
