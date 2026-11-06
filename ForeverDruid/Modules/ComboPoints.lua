-- Combo point pips under the HUD. The probe found combo points readable on Forever; if that ever
-- changes, the pips fall back to a number the client formats from the secret value.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("combopoints", {})

local COMBO = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
local MAX_PIPS = 5

local pips = {}

local function ReadComboPoints()
	local value
	if GetComboPoints then
		local ok, result = pcall(GetComboPoints, "player", "target")
		if ok then
			value = result
		end
	end
	if not ns.IsSecret(value) and value == nil then
		local ok, result = pcall(UnitPower, "player", COMBO)
		if ok then
			value = result
		end
	end
	return value
end
M.ReadComboPoints = ReadComboPoints

function M:Init()
	local cfg = ns.ModuleConfig("combopoints")
	local width = MAX_PIPS * cfg.size + (MAX_PIPS - 1) * cfg.spacing
	self.anchor = ns.CreateAnchor("combopoints", width, cfg.size, { "CENTER", "CENTER", 0, -196 }, L["Combo points"], { fade = true })

	for i = 1, MAX_PIPS do
		local pip = self.anchor:CreateTexture(nil, "ARTWORK")
		pip:SetColorTexture(1, 0.82, 0.1, 1)
		pips[i] = pip
		local back = self.anchor:CreateTexture(nil, "BACKGROUND")
		back:SetColorTexture(0, 0, 0, 0.55)
		pip.back = back
	end
	local text = self.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("CENTER")
	self.text = text

	ns.OnUnit("UNIT_POWER_FREQUENT", "player", function(_, _, powerType)
		if self.enabled and powerType == "COMBO_POINTS" then
			self:Update()
		end
	end)
	local function Refresh()
		if self.enabled then
			self:Refresh()
		end
	end
	ns.On("PLAYER_TARGET_CHANGED", Refresh)
	-- Older clients raise this instead of UNIT_POWER_FREQUENT; ignored if Forever doesn't have it.
	ns.On("UNIT_COMBO_POINTS", function()
		if self.enabled then
			self:Update()
		end
	end)
	ns.Listen("FD_FORM_CHANGED", Refresh)
	ns.Listen("FD_LOCK_CHANGED", Refresh)
end

function M:Layout()
	local cfg = ns.ModuleConfig("combopoints")
	local width = MAX_PIPS * cfg.size + (MAX_PIPS - 1) * cfg.spacing
	self.anchor:SetSize(width, cfg.size)
	for i, pip in ipairs(pips) do
		local x = (i - 1) * (cfg.size + cfg.spacing)
		pip.back:ClearAllPoints()
		pip.back:SetPoint("LEFT", self.anchor, "LEFT", x, 0)
		pip.back:SetSize(cfg.size, cfg.size)
		pip:ClearAllPoints()
		pip:SetPoint("CENTER", pip.back, "CENTER")
		pip:SetSize(cfg.size - 2, cfg.size - 2)
	end
end

function M:Update()
	local value = ns.Previewing() and 4 or ReadComboPoints() -- preview: four of five lit
	-- Check for a secret before any comparison: even == on a secret value raises an error.
	if ns.IsSecret(value) then
		for _, pip in ipairs(pips) do
			pip:Hide()
			pip.back:Hide()
		end
		self.text:SetFormattedText("%d", value)
		self.text:Show()
		return
	end
	self.text:Hide()
	local readable = tonumber(value) or 0
	for i, pip in ipairs(pips) do
		pip.back:Show()
		pip:SetShown(i <= readable)
	end
	-- Five points: everything turns red so a finisher is obvious.
	local full = readable >= MAX_PIPS
	for _, pip in ipairs(pips) do
		if full then
			pip:SetColorTexture(1, 0.25, 0.15, 1)
		else
			pip:SetColorTexture(1, 0.82, 0.1, 1)
		end
	end
end

function M:ShouldShow()
	local cfg = ns.ModuleConfig("combopoints")
	if ns.db.unlocked then
		return true
	end
	return not cfg.catOnly or ns.form == "cat"
end

function M:Refresh()
	self:Layout()
	if self:ShouldShow() then
		self.anchor:Show()
		self:Update()
	else
		self.anchor:Hide()
	end
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
