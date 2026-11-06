-- Diagnostics: records what this Forever client actually exposes, so modules can be tuned from
-- evidence instead of guesses. Snapshots land in WTF/Account/<account>/SavedVariables/ForeverDruid.lua
-- (written on logout or /reload). Works on any class.
--
-- Automatic snapshots: one at login (out of combat) and one shortly after the first combat of each
-- session. Manual: /fd probe.

local _, ns = ...

local MAX_SNAPSHOTS = 12

local POWER_TYPES = {
	mana = "Mana",
	rage = "Rage",
	energy = "Energy",
	comboPoints = "ComboPoints",
}

local RESTRICTIONS = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }

local function Describe(value)
	if ns.IsSecret(value) then
		return "<secret>"
	end
	local kind = type(value)
	if kind == "number" or kind == "string" or kind == "boolean" or kind == "nil" then
		return value
	end
	return "<" .. kind .. ">"
end

local function Copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = Describe(v)
	end
	return out
end

local function SafeCall(fn, ...)
	if not fn then
		return "<missing>"
	end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		return "<error: " .. tostring(a) .. ">"
	end
	if b ~= nil then
		return { Describe(a), Describe(b) }
	end
	return Describe(a)
end

local function PowerSnapshot()
	local out = {}
	for key, enumName in pairs(POWER_TYPES) do
		local powerType = Enum and Enum.PowerType and Enum.PowerType[enumName]
		if powerType then
			out[key] = {
				shouldBeSecret = Describe(ns.SecretPredicate("ShouldUnitPowerBeSecret", "player", powerType)),
				maxShouldBeSecret = Describe(ns.SecretPredicate("ShouldUnitPowerMaxBeSecret", "player", powerType)),
				value = SafeCall(UnitPower, "player", powerType),
				max = SafeCall(UnitPowerMax, "player", powerType),
			}
		end
	end
	return out
end

local function RestrictionSnapshot()
	local out = {}
	local api = C_RestrictedActions
	local enum = Enum and Enum.AddOnRestrictionType
	if not (api and api.GetAddOnRestrictionState and enum) then
		return "<missing>"
	end
	for _, name in ipairs(RESTRICTIONS) do
		if enum[name] then
			out[name] = SafeCall(api.GetAddOnRestrictionState, enum[name])
		end
	end
	return out
end

local function CooldownSnapshot()
	local out = {
		shouldCooldownsBeSecret = Describe(ns.SecretPredicate("ShouldCooldownsBeSecret")),
		hasDurationApi = C_Spell and C_Spell.GetSpellCooldownDuration ~= nil,
	}
	local cooldowns = ns.modules.cooldowns
	if cooldowns and cooldowns.stats then
		for k, v in pairs(cooldowns.stats) do
			out[k] = Describe(v)
		end
	end
	local spellID = ns.KnownSpell("barkskin") or ns.KnownSpell("innervate")
	if spellID and C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		if ok and type(info) == "table" then
			out.sample = { spellID = spellID, startTime = Describe(info.startTime), duration = Describe(info.duration) }
		else
			out.sample = { spellID = spellID, result = Describe(info) }
		end
	end
	return out
end

local function AuraSnapshot()
	local out = { shouldAurasBeSecret = Describe(ns.SecretPredicate("ShouldAurasBeSecret")) }
	if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
		for _, key in ipairs({ "markOfTheWild", "thorns", "omenOfClarity" }) do
			local name = ns.SpellName(key)
			local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
			if not ok then
				out[key] = "<error: " .. tostring(aura) .. ">"
			elseif ns.IsSecret(aura) then
				out[key] = "<secret>"
			elseif aura then
				out[key] = { spellId = Describe(aura.spellId), duration = Describe(aura.duration), name = Describe(aura.name) }
			else
				out[key] = "absent"
			end
		end
		local aura, restricted = ns.FindPlayerAura({ ns.AuraID("attuned") }, ns.SpellName("attuned"))
		if aura then
			out.attuned = { spellId = Describe(aura.spellId) }
		else
			out.attuned = restricted and "<restricted>" or "absent"
		end
	end
	return out
end

-- Which druid auras the client would keep secret (C_Secrets.ShouldSpellAuraBeSecret), by spell ID.
local AURA_CHECKS = {
	"clearcasting", "tigersFury", "barkskin", "naturesGrasp", "enrage", "frenziedRegeneration",
	"innervate", "dash", "naturesSwiftness", "markOfTheWild", "thorns", "omenOfClarity", "attuned",
}
local function AuraSecrecySnapshot()
	local out = {}
	for _, key in ipairs(AURA_CHECKS) do
		local id = ns.KnownSpell(key) or ns.AuraID(key)
		if id then
			out[key] = { id = id, secret = Describe(ns.SecretPredicate("ShouldSpellAuraBeSecret", id)) }
		end
	end
	return out
end

local function ModuleStats()
	local out = {}
	for key, module in pairs(ns.modules) do
		if type(module.stats) == "table" then
			out[key] = Copy(module.stats)
		end
	end
	return out
end

local function ApiSnapshot()
	return {
		UnitPowerPercent = UnitPowerPercent ~= nil,
		CreateCurve = C_CurveUtil ~= nil and C_CurveUtil.CreateCurve ~= nil,
		CreateColorCurve = C_CurveUtil ~= nil and C_CurveUtil.CreateColorCurve ~= nil,
		GetUnitAuras = C_UnitAuras ~= nil and C_UnitAuras.GetUnitAuras ~= nil,
		GetSpellPowerCost = C_Spell ~= nil and C_Spell.GetSpellPowerCost ~= nil,
		comboPointsRead = Describe(ns.modules.combopoints and ns.modules.combopoints.ReadComboPoints and ns.modules.combopoints.ReadComboPoints()),
		targetExists = Describe(ns.SafeReadable(UnitExists, "target")),
		targetCanAttack = Describe(ns.SafeReadable(UnitCanAttack, "player", "target")),
	}
end

local function ReagentSnapshot()
	local out = {}
	for spell, items in pairs(ns.REAGENTS) do
		local counts = {}
		for _, itemID in ipairs(items) do
			counts[tostring(itemID)] = SafeCall(C_Item and C_Item.GetItemCount, itemID)
		end
		out[spell] = counts
	end
	return out
end

---------------------------------------------------------------------------
-- Capability checks: what Forever lets addons see for features still waiting on that answer
-- (party HoT tracker, Clearcasting alert, missing-debuff warning, threat, swing timer).
-- Counted during play and saved with every snapshot. Nothing here changes what you see.
---------------------------------------------------------------------------

local caps = {
	auraAdded = { inCombat = 0, readableID = 0, secretID = 0, secretList = 0, clearcasting = 0 },
}
ns.capabilities = caps

-- Do "aura added" events still name the spell in combat? (Clearcasting alert)
ns.OnUnit("UNIT_AURA", "player", function(_, _, info)
	if not ns.InCombat() or ns.IsSecret(info) or type(info) ~= "table" then
		return
	end
	local added = info.addedAuras
	if ns.IsSecret(added) then
		caps.auraAdded.secretList = caps.auraAdded.secretList + 1
		return
	end
	if type(added) ~= "table" then
		return
	end
	for _, aura in ipairs(added) do
		caps.auraAdded.inCombat = caps.auraAdded.inCombat + 1
		local id = not ns.IsSecret(aura) and type(aura) == "table" and aura.spellId
		if not id or ns.IsSecret(id) then
			caps.auraAdded.secretID = caps.auraAdded.secretID + 1
		else
			caps.auraAdded.readableID = caps.auraAdded.readableID + 1
			if id == 16870 then
				caps.auraAdded.clearcasting = caps.auraAdded.clearcasting + 1
			end
		end
	end
end)

-- The combat log (what a swing timer would need) is marked restricted in Forever's API docs
-- (COMBAT_LOG_EVENT_UNFILTERED: HasRestrictions), so it isn't registered here: an addon touching a
-- restricted event can trigger the game's "blocked action" warning. Attack speed is still probed.

local function AuraListInfo(unit, filter)
	if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
		return nil
	end
	local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, 10)
	if not ok then
		return { error = true }
	end
	if ns.IsSecret(list) or type(list) ~= "table" then
		return { list = Describe(list) }
	end
	local first = list[1]
	local out = { count = #list }
	if first ~= nil then
		out.entry = ns.IsSecret(first) and "<secret>" or "table"
		if not ns.IsSecret(first) then
			out.spellId = Describe(first.spellId)
			out.expirationTime = ns.IsSecret(first.expirationTime) and "<secret>" or "readable"
		end
	end
	return out
end

local function CapabilitySnapshot()
	local out = {
		auraAdded = Copy(caps.auraAdded),
		assistedCombat = ns.modules.nextability and {
			available = ns.modules.nextability.Available(),
			reason = ns.modules.nextability.stats.reason,
			rotationSpells = C_AssistedCombat and C_AssistedCombat.GetRotationSpells
				and Describe(#(select(2, pcall(C_AssistedCombat.GetRotationSpells)) or {})) or "<missing>",
			next = C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
				and Describe(select(2, pcall(C_AssistedCombat.GetNextCastSpell, false))) or "<missing>",
		},
		threat = Describe(ns.SafeReadable(UnitThreatSituation, "player", "target")),
		threatRaw = UnitThreatSituation and Describe(select(2, pcall(UnitThreatSituation, "player", "target"))) or "<missing>",
		attackSpeed = UnitAttackSpeed and Describe(select(2, pcall(UnitAttackSpeed, "player"))) or "<missing>",
		target = AuraListInfo("target", "HARMFUL|PLAYER"),
		party = {},
	}
	for i = 1, 4 do
		local unit = "party" .. i
		if ns.SafeReadable(UnitExists, unit) then
			out.party[unit] = AuraListInfo(unit, "HELPFUL|PLAYER")
		end
	end
	return out
end

-- ForeverDruid's own CPU cost from the client's addon profiler (the same numbers as the AddOns
-- list's CPU readout). Milliseconds per frame; nil when the profiler is off or unavailable.
function ns.CpuUsage()
	local profiler = C_AddOnProfiler
	local metric = Enum and Enum.AddOnProfilerMetric
	if not (profiler and profiler.GetAddOnMetric and metric) then
		return nil
	end
	if profiler.IsEnabled and not ns.SafeReadable(profiler.IsEnabled) then
		return nil
	end
	local function Get(which)
		return tonumber(ns.SafeReadable(profiler.GetAddOnMetric, "ForeverDruid", which))
	end
	local function Overall(which)
		return profiler.GetOverallMetric and tonumber(ns.SafeReadable(profiler.GetOverallMetric, which))
	end
	return {
		recentMs = Get(metric.RecentAverageTime),
		sessionMs = Get(metric.SessionAverageTime),
		peakMs = Get(metric.PeakTime),
		ticksOver1Ms = Get(metric.CountTimeOver1Ms),
		ticksOver5Ms = Get(metric.CountTimeOver5Ms),
		allAddonsRecentMs = Overall(metric.RecentAverageTime),
	}
end

function ns.CpuSummary()
	local cpu = ns.CpuUsage()
	if not (cpu and cpu.recentMs) then
		return nil
	end
	local share = ""
	if cpu.allAddonsRecentMs and cpu.allAddonsRecentMs > 0 then
		share = (" (%d%% of all addons)"):format(math.floor(cpu.recentMs / cpu.allAddonsRecentMs * 100 + 0.5))
	end
	return ("CPU %.3f ms/frame recently%s, peak %.2f ms"):format(cpu.recentMs, share, cpu.peakMs or 0)
end

function ns.TakeSnapshot(tag)
	local version, build, buildDate, interface = GetBuildInfo()
	local _, classFile = UnitClass("player")
	local _, raceFile = UnitRace("player")
	local snapshot = {
		tag = tag,
		time = (date and date("%Y-%m-%d %H:%M:%S")) or "?",
		addonVersion = ns.VERSION,
		client = { version = version, build = build, date = buildDate, interface = interface },
		project = { id = WOW_PROJECT_ID, camelot = WOW_PROJECT_CAMELOT },
		player = { class = classFile, race = raceFile, level = UnitLevel("player") },
		inCombat = InCombatLockdown(),
		hasIsSecretValue = _G.issecretvalue ~= nil,
		hasCSecrets = _G.C_Secrets ~= nil,
		form = ns.GetForm and ns.GetForm(),
		role = ns.role,
		talentTrees = ns.GetTalentTrees and ns.GetTalentTrees() or "<missing>",
		shapeshiftForms = ns.ShapeshiftForms and ns.ShapeshiftForms(),
		power = PowerSnapshot(),
		restrictions = RestrictionSnapshot(),
		cooldowns = CooldownSnapshot(),
		auras = AuraSnapshot(),
		energyTick = ns.energyTickStats and Copy(ns.energyTickStats),
		reagents = ReagentSnapshot(),
		auraSecrecy = AuraSecrecySnapshot(),
		moduleStats = ModuleStats(),
		api = ApiSnapshot(),
		profile = ns.profileName,
		cpu = ns.CpuUsage(),
		capabilities = CapabilitySnapshot(),
		tints = ns.tintStats and Copy(ns.tintStats),
		layout = ns.db and { stack = ns.db.layout.stack, detached = Copy(ns.db.layout.detached), style = ns.db.style.icons },
	}
	if not snapshot.inCombat then
		snapshot.spellbook = ns.KnownSpellList()
		snapshot.passiveSpells = ns.PassiveSpellList()
	end

	ForeverDruidProbe = type(ForeverDruidProbe) == "table" and ForeverDruidProbe or {}
	ForeverDruidProbe.snapshots = ForeverDruidProbe.snapshots or {}
	local list = ForeverDruidProbe.snapshots
	list[#list + 1] = snapshot
	while #list > MAX_SNAPSHOTS do
		table.remove(list, 1)
	end
	return snapshot
end

function ns.PrintSnapshot(s)
	ns.Print(("probe '%s' (%s, combat=%s)"):format(s.tag, tostring(s.client.version), tostring(s.inCombat)))
	ns.Print(("form=%s role=%s"):format(tostring(s.form), tostring(s.role)))
	for key, p in pairs(s.power) do
		local value = type(p.value) == "table" and p.value[1] or p.value
		ns.Print(("  %s: value=%s secretPredicate=%s"):format(key, tostring(value), tostring(p.shouldBeSecret)))
	end
	ns.Print(("  cooldowns secret=%s durationApi=%s"):format(tostring(s.cooldowns.shouldCooldownsBeSecret), tostring(s.cooldowns.hasDurationApi)))
	ns.Print(("  auras secret=%s"):format(tostring(s.auras.shouldAurasBeSecret)))
	if s.energyTick then
		local tick = s.energyTick
		ns.Print(("  energy tick: mode=%s period=%s events=%s (cast-related %s)"):format(
			tostring(tick.mode), tostring(tick.period), tostring(tick.events), tostring(tick.castEvents)))
	end
	local secretAuras = {}
	for key, info in pairs(s.auraSecrecy or {}) do
		if info.secret == true then
			secretAuras[#secretAuras + 1] = key
		end
	end
	table.sort(secretAuras)
	ns.Print("  auras secret in combat: " .. (#secretAuras > 0 and table.concat(secretAuras, ", ") or "none reported"))
	local cpu = ns.CpuSummary()
	if cpu then
		ns.Print("  " .. cpu)
	end
	ns.Print("Saved. /reload or log out to write it to disk.")
end

local loginTaken, combatTaken = false, false

ns.On("PLAYER_ENTERING_WORLD", function()
	if loginTaken or not (ns.db and ns.db.probe.auto) then
		return
	end
	loginTaken = true
	C_Timer.After(5, function()
		ns.TakeSnapshot("login")
	end)
end)

ns.On("PLAYER_REGEN_DISABLED", function()
	if combatTaken or not (ns.db and ns.db.probe.auto) then
		return
	end
	combatTaken = true
	C_Timer.After(1.5, function()
		ns.TakeSnapshot("combat")
	end)
end)
