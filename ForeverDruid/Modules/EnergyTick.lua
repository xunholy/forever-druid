-- Energy tick timer for Cat Form.
--
-- Forever keeps the player's energy secret even out of combat (probe, 1.60.1.70790), so the value
-- can't be read. The *timing* of UNIT_POWER_FREQUENT events still can: with Classic-style regen the
-- client reports an energy change every 2 seconds, with continuous regen it reports many per second.
--   * Events within a short window after one of our own casts are spends/refunds, not ticks, and
--     are ignored.
--   * Once the gaps between the remaining events settle on ~2s, the module locks onto that phase and
--     keeps extrapolating it (no events arrive while energy is full).
--   * If events arrive much faster than ticks would, regen is continuous: the bar stays hidden.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("energytick", {})

local NOMINAL_PERIOD = 2.0
local CAST_WINDOW = 0.2 -- seconds after our own cast in which energy events are spends
local PHASE_TOLERANCE = 0.3
local MAX_GAPS = 12

local stats = {
	mode = "learning", -- "learning", "tick", "continuous"
	period = NOMINAL_PERIOD,
	phase = nil,
	events = 0,
	castEvents = 0,
	offPhase = 0,
}
ns.energyTickStats = stats

local gaps = {}
local lastEventTime
local lastCastTime = -math.huge

local function Median(list)
	local sorted = {}
	for i = 1, #list do
		sorted[i] = list[i]
	end
	table.sort(sorted)
	return sorted[math.floor((#sorted + 1) / 2)]
end

function M.ResetLearning()
	wipe(gaps)
	lastEventTime = nil
	stats.mode, stats.phase, stats.offPhase = "learning", nil, 0
	stats.period = NOMINAL_PERIOD
end

function M.NoteCast(now)
	lastCastTime = now
end

-- One energy-change event at time `now`. Pure timing logic, exposed for tests.
function M.Observe(now)
	stats.events = stats.events + 1
	if now - lastCastTime <= CAST_WINDOW then
		stats.castEvents = stats.castEvents + 1
		return
	end

	if stats.mode == "tick" and stats.phase then
		local offset = (now - stats.phase) % stats.period
		if offset <= PHASE_TOLERANCE or offset >= stats.period - PHASE_TOLERANCE then
			stats.phase = now
			stats.offPhase = 0
		else
			stats.offPhase = stats.offPhase + 1
			if stats.offPhase >= 3 then
				M.ResetLearning()
			end
		end
		return
	end

	if lastEventTime then
		local gap = now - lastEventTime
		-- Gaps of several periods (energy was full, or we were spending) fold back to one period.
		local multiple = math.floor(gap / NOMINAL_PERIOD + 0.5)
		if multiple >= 1 then
			gap = gap / multiple
		end
		gaps[#gaps + 1] = gap
		if #gaps > MAX_GAPS then
			table.remove(gaps, 1)
		end
		if #gaps >= 4 then
			local median = Median(gaps)
			if median > NOMINAL_PERIOD - 0.25 and median < NOMINAL_PERIOD + 0.25 then
				stats.mode = "tick"
				stats.period = median
				stats.phase = now
			elseif median < 0.75 and #gaps >= 8 then
				stats.mode = "continuous"
			end
		end
	end
	lastEventTime = now
end

function M:Init()
	local cfg = ns.ModuleConfig("energytick")
	local anchor = ns.CreateAnchor("energytick", cfg.width, cfg.height, { "CENTER", "CENTER", 0, -182 }, L["Energy tick"], { fade = true })
	self.anchor = anchor

	local bar = CreateFrame("StatusBar", nil, anchor)
	bar:SetAllPoints()
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(1.0, 0.85, 0.1, 0.9)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.5)

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetBlendMode("ADD")
	self.bar, self.spark = bar, spark
	bar:Hide()

	local elapsed = 0
	bar:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.02 then
			return
		end
		elapsed = 0
		self:UpdateSpark()
	end)

	ns.OnUnit("UNIT_POWER_FREQUENT", "player", function(_, _, powerType)
		if self.enabled and powerType == "ENERGY" and ns.form == "cat" then
			M.Observe(GetTime())
			self:Refresh()
		end
	end)
	ns.OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function()
		M.NoteCast(GetTime())
	end)
	local function Refresh()
		if self.enabled then
			self:Refresh()
		end
	end
	ns.Listen("FD_FORM_CHANGED", Refresh)
	ns.Listen("FD_LOCK_CHANGED", Refresh)
end

function M:UpdateSpark()
	local phase, period = stats.phase, stats.period
	if ns.Previewing() and (stats.mode ~= "tick" or not phase) then
		phase, period = 0, 2 -- preview a 2-second tick while unlocked, before any learning
	elseif stats.mode ~= "tick" or not phase then
		return
	end
	local progress = ((GetTime() - phase) % period) / period
	self.bar:SetValue(progress)
	self.spark:ClearAllPoints()
	self.spark:SetPoint("CENTER", self.bar, "LEFT", progress * self.bar:GetWidth(), 0)
end

function M:ShouldShow()
	if ns.db.unlocked then
		return true
	end
	local power = ns.modules.powerbar
	if power and power.CarriesTick and power:CarriesTick() then
		return false -- the energy bar draws the spark itself
	end
	return ns.form == "cat" and stats.mode == "tick"
end

function M:Refresh()
	local cfg = ns.ModuleConfig("energytick")
	self.anchor:SetSize(cfg.width, cfg.height)
	self.spark:SetSize(10, cfg.height * 3)
	-- Hide the whole row, not just the bar, so the stack closes up outside Cat Form.
	local show = self:ShouldShow() and true or false
	self.anchor:SetShown(show)
	self.bar:SetShown(show)
end

function M:Enable()
	self.anchor:Show()
	self:Refresh()
end

function M:Disable()
	self.bar:Hide()
	self.anchor:Hide()
end
