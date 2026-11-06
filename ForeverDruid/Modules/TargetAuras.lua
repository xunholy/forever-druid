-- "My effects on target": your DoTs on an enemy (Rake, Rip, Moonfire, Insect Swarm, Faerie Fire,
-- Demoralizing Roar, Lacerate…) or your HoTs on a friend (Rejuvenation, Regrowth…), big and next
-- to the HUD.
--
-- The list comes from C_UnitAuras.GetUnitAuras with a PLAYER filter, the same call Blizzard's
-- nameplates use. Every field is passed straight to a widget (icon texture, expiration time,
-- stack text), so the timers keep running in combat even when the values are secret.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("targetauras", {})

local icons = {}
M.stats = { queries = 0, failures = 0, shown = 0, secretEntries = 0 }

local HOSTILE_FILTER = "HARMFUL|PLAYER"
local FRIENDLY_FILTER = "HELPFUL|PLAYER"

-- Which filters to query for the current target. Unknown reaction → both.
function M.Filters()
	local exists = ns.SafeReadable(UnitExists, "target")
	if not exists then
		return {}
	end
	local canAttack = ns.SafeReadable(UnitCanAttack, "player", "target")
	if canAttack == true then
		return { HOSTILE_FILTER }
	elseif canAttack == false then
		return { FRIENDLY_FILTER }
	end
	return { HOSTILE_FILTER, FRIENDLY_FILTER }
end

-- Returns a list of AuraData tables (contents may be secret), capped at `max`.
function M.Collect(max)
	local out = {}
	if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
		return out
	end
	for _, filter in ipairs(M.Filters()) do
		M.stats.queries = M.stats.queries + 1
		local ok, list = pcall(C_UnitAuras.GetUnitAuras, "target", filter, max)
		if not ok or ns.IsSecret(list) or type(list) ~= "table" then
			M.stats.failures = M.stats.failures + 1
		else
			for _, aura in ipairs(list) do
				if #out >= max then
					return out
				end
				if ns.IsSecret(aura) then
					M.stats.secretEntries = M.stats.secretEntries + 1
				else
					out[#out + 1] = aura
				end
			end
		end
	end
	return out
end

local function StackText(aura)
	-- Prefer the client's formatter (handles secret counts) when the instance ID is usable.
	local id = aura.auraInstanceID
	if not ns.IsSecret(id) and id and C_UnitAuras.GetAuraApplicationDisplayCount then
		local ok, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "target", id, 2)
		if ok then
			return text
		end
	end
	local applications = aura.applications
	if ns.IsSecret(applications) then
		return ""
	end
	return (applications and applications > 1) and tostring(applications) or ""
end

local function IconFor(index, parent, size)
	local frame = icons[index]
	if not frame then
		frame = ns.CreateIcon(parent, size, { reverse = true, count = true, borderColor = { 0.6, 0.1, 0.1, 0.9 } })
		icons[index] = frame
	end
	frame:SetSize(size, size)
	return frame
end

-- Shown while unlocked: Rake, Rip and Moonfire with timers, plus a 3-stack.
function M.SampleList()
	return {
		ns.SampleAura(1822, 9, 6),
		ns.SampleAura(1079, 12, 10),
		ns.SampleAura(8921, 12, 3, 3),
	}
end

local function ApplyAura(frame, aura, friendly)
	frame.icon:SetTexture(aura.icon)
	local ok = pcall(frame.cooldown.SetCooldownFromExpirationTime, frame.cooldown, aura.expirationTime, aura.duration)
	if not ok then
		frame.cooldown:Clear()
	end
	frame.count:SetText(StackText(aura))
	if friendly then
		frame.border:SetColorTexture(0.1, 0.6, 0.2, 0.9)
	else
		frame.border:SetColorTexture(0.6, 0.1, 0.1, 0.9)
	end
end

function M:Init()
	local cfg = ns.ModuleConfig("targetauras")
	self.anchor = ns.CreateAnchor("targetauras", cfg.size, cfg.size, { "CENTER", "CENTER", 0, -140 }, L["My effects on target"], { fade = true })

	local function Queue()
		if self.enabled then
			ns.Debounce("targetauras", 0.05, function()
				if self.enabled then
					self:Refresh()
				end
			end)
		end
	end
	ns.OnUnit("UNIT_AURA", "target", Queue)
	ns.On("PLAYER_TARGET_CHANGED", Queue)
	ns.Listen("FD_LOCK_CHANGED", Queue)
	-- Auras can drop without an event reaching us (target out of range); re-check now and then.
	C_Timer.NewTicker(1, Queue)
end

function M:Refresh()
	local cfg = ns.ModuleConfig("targetauras")
	local previewing = ns.Previewing()
	local list = previewing and M.SampleList() or M.Collect(cfg.max)
	local friendly = not previewing and ns.SafeReadable(UnitCanAttack, "player", "target") == false
	local size, spacing = cfg.size, cfg.spacing
	local count = #list
	self.anchor:SetSize(math.max(size, count * size + math.max(count - 1, 0) * spacing), size)
	local shown = 0
	for i, aura in ipairs(list) do
		local frame = IconFor(i, self.anchor, size)
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (size + spacing), 0)
		local ok = pcall(ApplyAura, frame, aura, friendly)
		frame:SetShown(ok)
		if ok then
			shown = shown + 1
		end
	end
	for i = count + 1, #icons do
		icons[i]:Hide()
	end
	M.stats.shown = shown
	self.anchor:Show()
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
