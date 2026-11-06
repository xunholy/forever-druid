-- Alerts above the HUD: Clearcasting and Nature's Grace the moment they trigger, and a warning
-- when you're losing aggro in Bear Form.
--
-- Both depend on what Forever lets addons read in combat. Procs come from the "aura added" part of
-- UNIT_AURA, which may name the spell even when ordinary aura lookups are hidden; threat comes
-- from UnitThreatSituation. Whenever the client hides the answer, the alert simply doesn't show
-- (and the probe counts it), so nothing here can show something wrong.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("alerts", {})

M.PROCS = {
	{ key = "clearcasting", id = 16870 },
	{ key = "naturesGrace", id = 16886 },
}
local PROC_BY_ID = {}
for _, proc in ipairs(M.PROCS) do
	PROC_BY_ID[proc.id] = proc
end

local MAX_PROC_SECONDS = 15 -- longest proc; a safety net if the "removed" event never comes

M.stats = { procShown = 0, readableAdds = 0, secretAdds = 0, threatReadable = 0, threatSecret = 0, threatWarnings = 0 }
M.active = {} -- auraInstanceID -> { proc=, shownAt=, aura= }

local icons = {}
local banner

local function IconFor(index)
	local frame = icons[index]
	if not frame then
		local cfg = ns.ModuleConfig("alerts")
		frame = ns.CreateIcon(M.anchor, cfg.size, { reverse = true })
		icons[index] = frame
	end
	return frame
end

local function PlayAlertSound()
	if ns.ModuleConfig("alerts").sound and PlaySound then
		local kit = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12867
		pcall(PlaySound, kit, "Master")
	end
end

---------------------------------------------------------------------------
-- Procs
---------------------------------------------------------------------------

-- Records procs from a UNIT_AURA update. Returns true if something changed. Only readable spell IDs
-- count: a hidden one could be anything.
function M.ApplyAuraUpdate(info)
	if ns.IsSecret(info) or type(info) ~= "table" then
		return false
	end
	local changed = false
	local added = info.addedAuras
	if not ns.IsSecret(added) and type(added) == "table" then
		for _, aura in ipairs(added) do
			local id = not ns.IsSecret(aura) and type(aura) == "table" and aura.spellId
			if not id or ns.IsSecret(id) then
				M.stats.secretAdds = M.stats.secretAdds + 1
			else
				M.stats.readableAdds = M.stats.readableAdds + 1
				local proc = PROC_BY_ID[id]
				local instance = aura.auraInstanceID
				if proc and not ns.IsSecret(instance) and instance then
					M.active[instance] = { proc = proc, shownAt = GetTime(), aura = aura }
					M.stats.procShown = M.stats.procShown + 1
					changed = true
					PlayAlertSound()
				end
			end
		end
	end
	local removed = info.removedAuraInstanceIDs
	if not ns.IsSecret(removed) and type(removed) == "table" then
		for _, instance in ipairs(removed) do
			if not ns.IsSecret(instance) and M.active[instance] then
				M.active[instance] = nil
				changed = true
			end
		end
	end
	return changed
end

local function ExpireOld()
	local now = GetTime()
	for instance, entry in pairs(M.active) do
		local expires = ns.Readable(entry.aura.expirationTime)
		if (expires and expires > 0 and expires < now) or now - entry.shownAt > MAX_PROC_SECONDS then
			M.active[instance] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Threat (Bear Form)
---------------------------------------------------------------------------

-- 3 = securely tanking; anything lower means the target is on, or turning to, someone else.
function M.LosingAggro()
	local cfg = ns.ModuleConfig("alerts")
	if not cfg.threat or ns.form ~= "bear" or not ns.InCombat() then
		return false
	end
	if not ns.SafeReadable(UnitExists, "target") or ns.SafeReadable(UnitCanAttack, "player", "target") ~= true then
		return false
	end
	if not cfg.threatSolo and not (IsInGroup and ns.SafeReadable(IsInGroup)) then
		return false
	end
	if not UnitThreatSituation then
		return false
	end
	local ok, status = pcall(UnitThreatSituation, "player", "target")
	if not ok or ns.IsSecret(status) then
		M.stats.threatSecret = M.stats.threatSecret + 1
		return false
	end
	M.stats.threatReadable = M.stats.threatReadable + 1
	return type(status) == "number" and status < 3
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

function M:Init()
	local cfg = ns.ModuleConfig("alerts")
	self.anchor = ns.CreateAnchor("alerts", cfg.size, cfg.size, { "CENTER", "CENTER", 0, -92 }, L["Alerts"], { fade = false })

	banner = self.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	banner:SetPoint("BOTTOM", self.anchor, "TOP", 0, 4)
	banner:SetTextColor(1, 0.25, 0.15)
	banner:Hide()

	ns.OnUnit("UNIT_AURA", "player", function(_, _, info)
		if self.enabled and ns.ModuleConfig("alerts").procs and M.ApplyAuraUpdate(info) then
			self:Refresh()
		end
	end)
	ns.Listen("FD_LOCK_CHANGED", function()
		if self.enabled then
			self:Refresh()
		end
	end)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if self.enabled then
			self:Refresh()
		end
	end)
	C_Timer.NewTicker(0.25, function()
		if self.enabled then
			self:Refresh()
		end
	end)
end

function M:Refresh()
	local cfg = ns.ModuleConfig("alerts")
	ExpireOld()
	local list = {}
	if ns.Previewing() then
		list = { { proc = M.PROCS[1], aura = ns.SampleAura(16870, 15, 9) } }
	elseif cfg.procs then
		for _, entry in pairs(M.active) do
			list[#list + 1] = entry
		end
	end
	local size, spacing = cfg.size, 6
	self.anchor:SetSize(math.max(size, #list * size + math.max(#list - 1, 0) * spacing), size)
	for i, entry in ipairs(list) do
		local frame = IconFor(i)
		frame:SetSize(size, size)
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (size + spacing), 0)
		frame.icon:SetTexture(entry.aura.icon or ns.SpellIcon(entry.proc.id))
		pcall(frame.cooldown.SetCooldownFromExpirationTime, frame.cooldown, entry.aura.expirationTime, entry.aura.duration)
		if frame.fdShownFor ~= entry then
			frame.fdShownFor = entry
			ns.Pulse(frame)
		end
		frame:Show()
	end
	for i = #list + 1, #icons do
		icons[i]:Hide()
		icons[i].fdShownFor = nil
	end

	local losing = ns.Previewing() or M.LosingAggro()
	if losing and not banner:IsShown() and not ns.Previewing() then
		M.stats.threatWarnings = M.stats.threatWarnings + 1
		PlayAlertSound()
	end
	banner:SetText(L["Losing aggro!"])
	banner:SetShown(losing and true or false)
	self.anchor:Show()
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
