-- Player buffs and procs worth watching as a druid: Clearcasting, Tiger's Fury, Barkskin, Nature's
-- Grasp, Enrage, Frenzied Regeneration, Innervate, Dash, Nature's Swiftness.
--
-- Lookup goes by spell ID first (works in combat for any aura the client doesn't keep secret) and
-- by name out of combat (catches ranks). Timers use Cooldown:SetCooldownFromExpirationTime, which
-- accepts secret times, so a buff found in combat still counts down. When the client refuses to
-- answer for an aura in combat, the icon keeps its last readable state, dimmed, and the probe counts it.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("buffs", {})

-- key: catalogue key (spell or aura). roles: where it's worth showing (nil = everywhere).
M.TRACKED = {
	{ key = "clearcasting", aura = true },
	{ key = "tigersFury", roles = { cat = true } },
	{ key = "enrage", roles = { bear = true } },
	{ key = "frenziedRegeneration", roles = { bear = true } },
	{ key = "barkskin" },
	{ key = "naturesGrasp" },
	{ key = "naturesSwiftness" },
	{ key = "innervate" },
	{ key = "dash" },
}

local icons = {}
M.stats = { lookups = 0, restricted = 0, shown = 0 }
M.active = {}

local function CandidateIDs(entry)
	local ids = {}
	if not entry.aura then
		local known = ns.KnownSpell(entry.key)
		if known then
			ids[#ids + 1] = known
		end
	end
	local fixed = ns.AuraID(entry.key)
	if fixed then
		ids[#ids + 1] = fixed
	end
	return ids
end

local lastSeen = {} -- key -> aura from the last readable lookup
local lastSeenAt = {} -- key -> GetTime() of that lookup
local MAX_STALE_SECONDS = 30 -- longest tracked buff; caps icons whose expiry is itself secret

-- Returns { {key=, aura=, stale=}, ... } for tracked buffs currently on the player. When the client
-- refuses a lookup (secret in combat) the last readable result is reused and marked stale, so the
-- icon stays up (dimmed) with its timer still running instead of vanishing.
function M.Collect(role)
	local found = {}
	for _, entry in ipairs(M.TRACKED) do
		if not entry.roles or entry.roles[role] then
			M.stats.lookups = M.stats.lookups + 1
			-- Name lookup only out of combat; in combat it would just be refused.
			local name = not ns.InCombat() and ns.SpellName(entry.key) or nil
			local aura, restricted = ns.FindPlayerAura(CandidateIDs(entry), name)
			if aura then
				lastSeen[entry.key] = aura
				lastSeenAt[entry.key] = GetTime()
				found[#found + 1] = { key = entry.key, aura = aura }
			elseif restricted then
				M.stats.restricted = M.stats.restricted + 1
				local previous = lastSeen[entry.key]
				local expires = previous and ns.Readable(previous.expirationTime)
				local age = GetTime() - (lastSeenAt[entry.key] or 0)
				if (expires and expires > 0 and expires < GetTime()) or age > MAX_STALE_SECONDS then
					-- Its timer has run out (or we can't tell and it's been too long): drop it.
					lastSeen[entry.key] = nil
				elseif previous then
					found[#found + 1] = { key = entry.key, aura = previous, stale = true }
				end
			else
				lastSeen[entry.key] = nil
			end
		end
	end
	return found
end

local function IconFor(index, parent, size)
	local frame = icons[index]
	if not frame then
		frame = ns.CreateIcon(parent, size, { reverse = true, count = true })
		icons[index] = frame
	end
	frame:SetSize(size, size)
	return frame
end

-- Shown while unlocked so the row has something to arrange: Clearcasting, Tiger's Fury, Barkskin.
function M.SampleList()
	return {
		{ key = "clearcasting", aura = ns.SampleAura(16870, 15, 11) },
		{ key = "tigersFury", aura = ns.SampleAura(5217, 6, 4) },
		{ key = "barkskin", aura = ns.SampleAura(22812, 15, 9) },
	}
end

local function ApplyAura(frame, aura)
	-- All of these accept secret values from addon code.
	frame.icon:SetTexture(aura.icon)
	local ok = pcall(frame.cooldown.SetCooldownFromExpirationTime, frame.cooldown, aura.expirationTime, aura.duration)
	if not ok then
		frame.cooldown:Clear()
	end
	local applications = aura.applications
	if ns.IsSecret(applications) then
		frame.count:SetText("")
	else
		frame.count:SetText((applications and applications > 1) and applications or "")
	end
end

function M:Init()
	local cfg = ns.ModuleConfig("buffs")
	self.anchor = ns.CreateAnchor("buffs", cfg.size, cfg.size, { "CENTER", "CENTER", 0, -262 }, L["Buffs & procs"], { fade = true })

	local function Queue()
		if self.enabled then
			ns.Debounce("buffs", 0.05, function()
				if self.enabled then
					self:Refresh()
				end
			end)
		end
	end
	ns.OnUnit("UNIT_AURA", "player", Queue)
	ns.Listen("FD_ROLE_CHANGED", Queue)
	ns.Listen("FD_SPELLS_CHANGED", Queue)
	ns.Listen("FD_LOCK_CHANGED", Queue)
end

function M:Refresh()
	local cfg = ns.ModuleConfig("buffs")
	local list = ns.Previewing() and M.SampleList() or M.Collect(ns.role)
	M.active = list
	local size, spacing = cfg.size, cfg.spacing
	local count = #list
	self.anchor:SetSize(math.max(size, count * size + math.max(count - 1, 0) * spacing), size)
	for i, item in ipairs(list) do
		local frame = IconFor(i, self.anchor, size)
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (size + spacing), 0)
		local ok = pcall(ApplyAura, frame, item.aura)
		frame:SetAlpha(item.stale and 0.5 or 1)
		frame:SetShown(ok)
	end
	for i = count + 1, #icons do
		icons[i]:Hide()
	end
	M.stats.shown = count
	self.anchor:Show()
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
