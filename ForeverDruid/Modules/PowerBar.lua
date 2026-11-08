-- Energy in Cat Form, rage in Bear Form, as a bar in the HUD column.
--
-- Forever keeps the player's energy and rage secret from addons (probe), but a StatusBar accepts
-- the secret value and draws it, and the maximum is readable.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("powerbar", {})

local POWER = (Enum and Enum.PowerType) or {}
local ENERGY = POWER.Energy or 3
local RAGE = POWER.Rage or 1

local KINDS = {
	cat = { power = ENERGY, token = "ENERGY", color = { 1, 0.85, 0.1 } },
	bear = { power = RAGE, token = "RAGE", color = { 0.85, 0.12, 0.12 } },
}
M.KINDS = KINDS

function M:Kind()
	return KINDS[ns.form]
end

function M:ShouldShow()
	if ns.db.unlocked then
		return true
	end
	return self:Kind() ~= nil
end

function M:Init()
	local cfg = ns.ModuleConfig("powerbar")
	self.anchor = ns.CreateAnchor("powerbar", cfg.width, cfg.height, { "CENTER", "CENTER", 0, -160 }, L["Energy / rage"], { fade = true })

	local bar = CreateFrame("StatusBar", nil, self.anchor)
	bar:SetAllPoints()
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 100)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.55)
	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER")
	self.bar, self.text = bar, text

	ns.OnUnit("UNIT_POWER_FREQUENT", "player", function(_, _, token)
		local kind = self:Kind()
		if self.enabled and kind and token == kind.token then
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
end

function M:Update()
	local kind = self:Kind() or KINDS.cat
	local cfg = ns.ModuleConfig("powerbar")
	local value = UnitPower("player", kind.power) -- secret on Forever; only widgets see it
	local smooth = cfg.smooth and Enum and Enum.StatusBarInterpolation
	if smooth then
		self.bar:SetValue(value, smooth.ExponentialEaseOut)
	else
		self.bar:SetValue(value)
	end
	if cfg.text then
		self.text:SetFormattedText("%d", value)
		self.text:Show()
	else
		self.text:Hide()
	end
end

function M:Refresh()
	local cfg = ns.ModuleConfig("powerbar")
	self.anchor:SetSize(cfg.width, cfg.height)
	local show = self:ShouldShow() and true or false
	self.anchor:SetShown(show)
	if show then
		local kind = self:Kind() or KINDS.cat
		local max = ns.SafeReadable(UnitPowerMax, "player", kind.power)
		self.bar:SetMinMaxValues(0, (tonumber(max) or 0) > 0 and max or 100)
		self.bar:SetStatusBarColor(kind.color[1], kind.color[2], kind.color[3])
		self:Update()
	end
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
