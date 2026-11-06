-- The five-second rule: spending mana pauses your normal mana regeneration for five seconds.
-- A thin bar fills over those five seconds after every mana-spending cast, so you can see when
-- regen comes back (for healing, Balance, and timing a powershift).
--
-- It works from cast timing, not from your mana (which is secret on Forever). Whether a cast
-- spent mana comes from the spell's cost, cached when readable; when the client hides the spell
-- ID in combat, a cast counts as mana-spending unless you're in Cat or Bear Form, where abilities
-- cost energy or rage instead. The row keeps its space while shown so the column never jumps.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("fsr", {})

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local DURATION = 5

M.stats = { casts = 0, manaCasts = 0, secretIDs = 0 }
local manaCost = {} -- spellID -> true/false
local lastSpend

local function InForm()
	return ns.form == "cat" or ns.form == "bear"
end

function M.SpendsMana(spellID)
	if ns.IsSecret(spellID) or type(spellID) ~= "number" then
		M.stats.secretIDs = M.stats.secretIDs + 1
		return not InForm()
	end
	local cached = manaCost[spellID]
	if cached ~= nil then
		return cached
	end
	local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
	if not ok or ns.IsSecret(costs) or type(costs) ~= "table" then
		return not InForm()
	end
	local mana = false
	for _, entry in ipairs(costs) do
		local kind = ns.Readable(entry.type)
		local cost = ns.Readable(entry.cost) or ns.Readable(entry.minCost)
		if kind == MANA and type(cost) == "number" and cost > 0 then
			mana = true
		end
	end
	manaCost[spellID] = mana
	return mana
end

function M.NoteCast(spellID, now)
	M.stats.casts = M.stats.casts + 1
	if M.SpendsMana(spellID) then
		M.stats.manaCasts = M.stats.manaCasts + 1
		lastSpend = now or GetTime()
		return true
	end
	return false
end

-- 0..1 through the five seconds, or nil when regen is running.
function M.Progress(now)
	if ns.Previewing() then
		return ((now or GetTime()) % DURATION) / DURATION
	end
	if not lastSpend then
		return nil
	end
	local elapsed = (now or GetTime()) - lastSpend
	if elapsed >= DURATION or elapsed < 0 then
		return nil
	end
	return elapsed / DURATION
end

function M:ShouldShow()
	if ns.db.unlocked then
		return true
	end
	local cfg = ns.ModuleConfig("fsr")
	if cfg.casterOnly and InForm() then
		return false
	end
	return true
end

function M:Init()
	local cfg = ns.ModuleConfig("fsr")
	self.anchor = ns.CreateAnchor("fsr", cfg.width, cfg.height, { "CENTER", "CENTER", 0, -176 }, L["Five-second rule"], { fade = true })
	local bar = CreateFrame("StatusBar", nil, self.anchor)
	bar:SetAllPoints()
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.45, 0.7, 1, 0.9)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.4)
	bar:Hide()
	self.bar = bar

	self.anchor:SetScript("OnUpdate", function()
		self:UpdateBar()
	end)

	ns.OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
		if self.enabled and M.NoteCast(spellID) then
			self:UpdateBar()
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

function M:UpdateBar()
	local progress = M.Progress()
	if progress then
		self.bar:SetValue(progress)
		self.bar:Show()
	else
		self.bar:Hide()
	end
end

function M:Refresh()
	local cfg = ns.ModuleConfig("fsr")
	self.anchor:SetSize(cfg.width, cfg.height)
	self.anchor:SetShown(self:ShouldShow() and true or false)
	self:UpdateBar()
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
