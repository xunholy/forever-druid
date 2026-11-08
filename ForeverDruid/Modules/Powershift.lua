-- Powershifting: how many shifts your mana affords (pips), and a "Powershift" cue when it's worth
-- doing (Cat: energy low, Bear: rage low, you can afford the shift, and you have Furor). Forever's
-- energy refills continuously, so there's no tick to wait for.
--
-- Your mana, energy and rage are hidden from addons on Forever, so nothing here reads them. Each
-- pip's visibility comes from a curve on your mana percentage that the client evaluates; the cue
-- is two nested frames, one faded by an energy (or rage) curve and one by a mana curve, so it only
-- shows when both hold (the client multiplies their alphas). The shift's mana cost is readable.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("powershift", {})

local POWER = (Enum and Enum.PowerType) or {}
local MANA, ENERGY, RAGE = POWER.Mana or 0, POWER.Energy or 3, POWER.Rage or 1
local MAX_PIPS = 5

M.stats = { curveBuilds = 0, cueChecks = 0, noFuror = 0 }
local pips = {}
local pipCurves = {} -- [k] = curve with its step at k shifts' worth of mana
local manaCurve, lowCurve = nil, {}
local builtFor -- cost fraction the curves were built for

local function Step(at)
	if not (C_CurveUtil and C_CurveUtil.CreateCurve) then
		return nil
	end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if not ok or not curve then
		return nil
	end
	local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear
	if linear and curve.SetType then
		curve:SetType(linear)
	end
	at = math.max(0.002, math.min(at, 1))
	curve:AddPoint(0, 0)
	curve:AddPoint(at - 0.001, 0)
	curve:AddPoint(at, 1)
	curve:AddPoint(1, 1)
	return curve
end

-- Visible at or below `at` (for "energy is low"), gone just above it.
local function Below(at)
	if not (C_CurveUtil and C_CurveUtil.CreateCurve) then
		return nil
	end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if not ok or not curve then
		return nil
	end
	local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear
	if linear and curve.SetType then
		curve:SetType(linear)
	end
	curve:AddPoint(0, 1)
	curve:AddPoint(at, 1)
	curve:AddPoint(math.min(at + 0.02, 1), 0)
	curve:AddPoint(1, 0)
	return curve
end

local function BuildCurves(cost)
	if builtFor == cost then
		return
	end
	builtFor = cost
	M.stats.curveBuilds = M.stats.curveBuilds + 1
	wipe(pipCurves)
	for k = 1, MAX_PIPS do
		if k * cost <= 1 then
			pipCurves[k] = Step(k * cost)
		end
	end
	manaCurve = Step(cost)
end

local function LowCurve(threshold)
	if not lowCurve[threshold] then
		lowCurve[threshold] = Below(threshold)
	end
	return lowCurve[threshold]
end

function M.HasFuror()
	return ns.IsKnown("furor")
end

local function Kind()
	if ns.form == "cat" then
		return ENERGY
	elseif ns.form == "bear" then
		return RAGE
	end
end

function M:ShouldShow()
	if ns.db.unlocked then
		return true
	end
	return Kind() ~= nil
end

function M:Init()
	local cfg = ns.ModuleConfig("powershift")
	local width = MAX_PIPS * cfg.size + (MAX_PIPS - 1) * 3
	self.anchor = ns.CreateAnchor("powershift", width, cfg.size, { "CENTER", "CENTER", 0, -205 }, L["Powershift"], { fade = true })
	for i = 1, MAX_PIPS do
		local back = self.anchor:CreateTexture(nil, "BACKGROUND")
		back:SetColorTexture(0, 0, 0, 0.5)
		local pip = self.anchor:CreateTexture(nil, "ARTWORK")
		pip:SetColorTexture(0.25, 0.55, 1, 1)
		pip.back = back
		pips[i] = pip
	end

	-- The cue: outer frame faded by "energy/rage is low", inner by "mana affords a shift".
	local outer = CreateFrame("Frame", nil, self.anchor)
	outer:SetSize(130, 22)
	outer:SetPoint("LEFT", self.anchor, "RIGHT", 8, 0)
	local inner = CreateFrame("Frame", nil, outer)
	inner:SetAllPoints()
	local icon = inner:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("LEFT")
	icon:SetTexture(ns.SpellIcon(768))
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local text = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	text:SetTextColor(0.45, 0.85, 1)
	text:SetText(L["Powershift"])
	outer:Hide()
	self.cueOuter, self.cueInner, self.cueIcon = outer, inner, icon

	local function Update()
		if self.enabled then
			local ok, err = pcall(self.Update, self)
			if not ok then
				ns.ReportError(err)
			end
		end
	end
	ns.OnUnit("UNIT_POWER_FREQUENT", "player", Update)
	ns.OnUnit("UNIT_MAXPOWER", "player", function()
		builtFor = nil
		Update()
	end)
	ns.Listen("FD_FORM_CHANGED", function()
		if self.enabled then
			self:Refresh()
		end
	end)
	ns.Listen("FD_SPELLS_CHANGED", function()
		builtFor = nil
		Update()
	end)
	ns.Listen("FD_LOCK_CHANGED", function()
		if self.enabled then
			self:Refresh()
		end
	end)
	C_Timer.NewTicker(0.2, function() -- tick timing moves without events
		if self.anchor:IsShown() then
			Update()
		end
	end)
end

function M:Layout()
	local cfg = ns.ModuleConfig("powershift")
	local width = MAX_PIPS * cfg.size + (MAX_PIPS - 1) * 3
	self.anchor:SetSize(width, cfg.size)
	for i, pip in ipairs(pips) do
		pip.back:ClearAllPoints()
		pip.back:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (cfg.size + 3), 0)
		pip.back:SetSize(cfg.size, cfg.size)
		pip:ClearAllPoints()
		pip:SetPoint("CENTER", pip.back, "CENTER")
		pip:SetSize(cfg.size - 2, cfg.size - 2)
	end
end

function M:Update()
	local cfg = ns.ModuleConfig("powershift")
	local previewing = ns.Previewing()
	local formName = ns.form == "bear" and "bear" or "cat"
	local cost = ns.modules.manabar and ns.modules.manabar.ShiftCostFraction and ns.modules.manabar.ShiftCostFraction(formName)

	-- Pips: one per shift your mana affords.
	if previewing then
		for i, pip in ipairs(pips) do
			pip:SetAlpha(i <= 3 and 1 or 0)
			pip.back:SetShown(true)
		end
	elseif cfg.pips and cost and cost > 0 and UnitPowerPercent then
		BuildCurves(cost)
		for i, pip in ipairs(pips) do
			local curve = pipCurves[i]
			if curve then
				local ok, alpha = pcall(UnitPowerPercent, "player", MANA, false, curve)
				-- Never "ok and alpha or 0": that would test the hidden value.
				if ok then
					pip:SetAlpha(alpha) -- the client applies the hidden value
				else
					pip:SetAlpha(0)
				end
				pip.back:SetShown(true)
			else
				pip:SetAlpha(0)
				pip.back:SetShown(false) -- more shifts than a full bar of mana
			end
		end
	else
		for _, pip in ipairs(pips) do
			pip:SetAlpha(0)
			pip.back:SetShown(false)
		end
	end

	-- The cue (curves follow the current form's cost even with the pips off).
	if cost and cost > 0 then
		BuildCurves(cost)
	end
	local kind = Kind()
	local show = false
	if previewing then
		show = true
		self.cueOuter:SetAlpha(1)
		self.cueInner:SetAlpha(1)
	elseif cfg.cue and kind and cost and ns.InCombat() and UnitPowerPercent then
		M.stats.cueChecks = M.stats.cueChecks + 1
		if not M.HasFuror() then
			M.stats.noFuror = M.stats.noFuror + 1
		else
			local low = LowCurve(kind == ENERGY and cfg.energyBelow or cfg.rageBelow)
			local okLow, lowAlpha = pcall(UnitPowerPercent, "player", kind, false, low)
			local okMana, manaAlpha = pcall(UnitPowerPercent, "player", MANA, false, manaCurve)
			if okLow and okMana then
				self.cueOuter:SetAlpha(lowAlpha)
				self.cueInner:SetAlpha(manaAlpha)
				show = true
			end
		end
	end
	self.cueIcon:SetTexture(ns.SpellIcon(ns.form == "bear" and 5487 or 768))
	self.cueOuter:SetShown(show)
end

function M:Refresh()
	self:Layout()
	local show = self:ShouldShow() and true or false
	self.anchor:SetShown(show)
	if show then
		self:Update()
	end
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
