-- Mana bar shown while in Cat or Bear Form, where the player frame only shows energy or rage.
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

function M:Init()
	local cfg = ns.ModuleConfig("manabar")
	BuildCurves()
	local anchor = ns.CreateAnchor("manabar", cfg.width, cfg.height, { "CENTER", "CENTER", 0, -170 }, L["Mana bar"], { fade = true })
	self.anchor = anchor

	local bar = CreateFrame("StatusBar", nil, anchor)
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

	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER")

	self.bar, self.text, self.marker = bar, text, marker
	bar:Hide()

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

function M:UpdateMarker()
	local cfg = ns.ModuleConfig("manabar")
	local fraction = cfg.shiftMarker and M.ShiftCostFraction(ns.form)
	if fraction then
		self.marker:ClearAllPoints()
		self.marker:SetPoint("TOP", self.bar, "TOPLEFT", fraction * cfg.width, 0)
		self.marker:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", fraction * cfg.width, 0)
		self.marker:Show()
	else
		self.marker:Hide()
	end
end

function M:UpdateColor()
	local cfg = ns.ModuleConfig("manabar")
	if cfg.colorByLevel then
		local ok, color = PercentThrough(M.colorCurve)
		-- The color object itself is a plain table whose r/g/b may be secret; only a secret
		-- object (or a failed call) forces the fallback color.
		if ok and not ns.IsSecret(color) and type(color) == "table" and color.GetRGB then
			local applied = pcall(function()
				self.bar:SetStatusBarColor(color:GetRGB())
			end)
			if applied then
				return
			end
		end
	end
	self.bar:SetStatusBarColor(BASE_COLOR[1], BASE_COLOR[2], BASE_COLOR[3])
end

function M:UpdateText()
	local cfg = ns.ModuleConfig("manabar")
	local mode = cfg.text
	if mode == "none" then
		self.text:SetText("")
		return
	end
	local current = UnitPower("player", MANA)
	local maximum = UnitPowerMax("player", MANA)
	local hasPercent, percent = false, nil
	if mode == "percent" or mode == "both" then
		hasPercent, percent = PercentThrough(M.percentCurve)
	end
	if mode == "percent" and hasPercent then
		self.text:SetFormattedText("%.0f%%", percent)
	elseif mode == "both" and hasPercent then
		self.text:SetFormattedText("%d  (%.0f%%)", current, percent)
	else
		-- Works for secret values too: the client formats them without exposing them to Lua.
		self.text:SetFormattedText("%d / %d", current, maximum)
	end
end

function M:Update()
	self.bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
	-- Smooth: the client eases the bar toward the new value (works with the secret value).
	local smooth = ns.ModuleConfig("manabar").smooth and Enum and Enum.StatusBarInterpolation
	if smooth then
		self.bar:SetValue(UnitPower("player", MANA), smooth.ExponentialEaseOut)
	else
		self.bar:SetValue(UnitPower("player", MANA))
	end
	self:UpdateColor()
	self:UpdateText()
end

function M:Refresh()
	local cfg = ns.ModuleConfig("manabar")
	self.anchor:SetSize(cfg.width, cfg.height)
	-- Hide the whole row, not just the bar, so the stack closes up in caster form.
	local show = self:ShouldShow() and true or false
	self.anchor:SetShown(show)
	if show then
		self:Update()
		self:UpdateMarker()
		self.bar:Show()
	else
		self.bar:Hide()
	end
end

function M:Enable()
	self.anchor:Show()
	self:Refresh()
end

function M:Disable()
	self.bar:Hide()
	self.anchor:Hide()
end
