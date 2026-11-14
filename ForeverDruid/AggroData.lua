-- Aggro radius maths, the pull log and learning, for the Aggro radius part (Modules/AggroRadius.lua).
--
-- No game API gives a mob's aggro radius and no public Forever source publishes one: the Forever aggro
-- addons, the wiki and the private-server databases all start from the same in-game-testing estimate
-- (warcraft.wiki.gg/wiki/Aggro_radius): about 20 yards against a mob of your level, about 1 yard more
-- or less per level of difference, at least 5 and at most 45. On Forever the first measured pulls
-- (eight, levels 37-39, November 2026) all agreed on about 13 yards at equal level in range-readout
-- yards, so the starting base is 14 rather than 20. That is still only the starting point. The
-- source of truth is this client's own pulls: when a mob comes at you, the server's check fired
-- between the last calm range reading and the pull reading, so the radius lies within the span of
-- those two brackets. Each pull is stored as that interval on a level-neutral base, in range-readout
-- yards, so any gap between the client's range checks and the server's aggro check (such as the size
-- of a big mob) is learned with it.
--
-- The log lives in ForeverDruidProbe.aggro alongside the probe snapshots, and never leaves the PC.

local _, ns = ...

local A = {}
ns.aggro = A

A.BASE_RADIUS = 14
A.MIN_RADIUS = 5
A.MAX_RADIUS = 45

-- Auras that change a mob's detection range (aura type 91, MOD_DETECT_RANGE), from Forever's own
-- client data: wago.tools SpellEffect, product wowf, build 1.60.1.70888. No Forever spell changes the
-- range at which the player is detected (aura type 92 entries all have 0 or 1 points).
A.DETECT_RANGE_AURAS = {
	[453] = -10, -- Mind Soothe
	[8192] = -10, -- Mind Soothe
	[10953] = -10, -- Mind Soothe
	[2908] = -10, -- Soothe Animal
	[8955] = -10, -- Soothe Animal
	[9901] = -10, -- Soothe Animal
}

A.colors = {
	inside = { 1, 0.15, 0.1 }, -- you're inside the radius
	edge = { 1, 0.5, 0 }, -- your distance bracket overlaps it
	near = { 1, 0.85, 0.15 }, -- within the margin outside it
	safe = { 0.35, 0.85, 0.35 },
	unknown = { 0.6, 0.6, 0.6 }, -- the client gave no range reading
}
A.SEVERITY = { unknown = 0, safe = 1, near = 2, edge = 3, inside = 4 }

---------------------------------------------------------------------------
-- Threat on a mob that's fighting
---------------------------------------------------------------------------

-- UnitThreatSituation: 3 = it's on you and safely so, 2 = on you but someone has more threat,
-- 1 = not on you but you have more threat than its target, 0 = not on you.
-- A tank wants 3 (green) and a healer or Cat wants 0, so the colours run opposite ways.
local TANK_COLOR = { [3] = "safe", [2] = "near", [1] = "edge", [0] = "inside" }
local OTHER_COLOR = { [0] = "safe", [1] = "near", [2] = "edge", [3] = "inside" }

local function ReadThreat(field, fn, ...)
	if not fn then
		return nil
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		return nil
	end
	if ns.IsSecret(a) or ns.IsSecret(b) or ns.IsSecret(c) or ns.IsSecret(d) then
		A.CountSecret(field)
		return nil
	end
	return a, b, c, d
end

-- Your threat on a unit: colour key and a percentage label, or nil when you're not on its threat
-- table or Forever hides it. As a tank the label is your lead over the next player (130% = 30%
-- ahead); otherwise it's how close you are to pulling it (100% = it turns on you).
function A.Threat(unit, tanking)
	local status = ReadThreat("threat", UnitThreatSituation, "player", unit)
	if type(status) ~= "number" then
		return nil
	end
	local color = (tanking and TANK_COLOR or OTHER_COLOR)[status]
	if not color then
		return nil
	end
	local isTanking, _, _, raw = ReadThreat("threatPct", UnitDetailedThreatSituation, "player", unit)
	local pct = raw
	if isTanking then
		pct = ReadThreat("threatPct", UnitThreatPercentageOfLead, "player", unit) or raw
	end
	local text = type(pct) == "number" and pct > 0 and ("%d%%"):format(math.floor(pct + 0.5)) or ""
	return color, text, status
end

---------------------------------------------------------------------------
-- The pull log (ForeverDruidProbe.aggro)
---------------------------------------------------------------------------

-- Only pulls that can be learned from are kept (about one in seventy in play: most pulls are you
-- attacking first). The rest are counted by reason in log.counts and dropped, so they can never push
-- a learned pull out of the log.
local MAX_PULLS = 2000
local LOG_VERSION = 2
-- A pull only counts as proximity aggro when you hadn't cast or swung this recently.
A.ACTION_GRACE = 2

local lastAction = -math.huge

function A.Log()
	ForeverDruidProbe = type(ForeverDruidProbe) == "table" and ForeverDruidProbe or {}
	local log = ForeverDruidProbe.aggro
	if type(log) ~= "table" then
		log = {}
		ForeverDruidProbe.aggro = log
	end
	log.pulls = type(log.pulls) == "table" and log.pulls or {}
	log.secret = type(log.secret) == "table" and log.secret or {}
	log.readings = type(log.readings) == "table" and log.readings or { ranged = 0, noRange = 0, noRangeInCombat = 0 }
	log.counts = type(log.counts) == "table" and log.counts or {}
	return log
end

function A.CountSecret(field)
	local secret = A.Log().secret
	secret[field] = (secret[field] or 0) + 1
end

function A.CountReading(hasRange, playerInCombat)
	local r = A.Log().readings
	if hasRange then
		r.ranged = (r.ranged or 0) + 1
	elseif playerInCombat then
		r.noRangeInCombat = (r.noRangeInCombat or 0) + 1
	else
		r.noRange = (r.noRange or 0) + 1
	end
end

function A.NoteAction()
	lastAction = GetTime()
end

local function Plain(v)
	if ns.IsSecret(v) then
		return nil
	end
	return v
end

-- before: the unit's last calm reading; info: the reading that showed it in combat;
-- pullMin/pullMax: the range bracket at that moment.
function A.RecordPull(unit, before, info, pullMin, pullMax)
	if not before or before.radius == nil then
		return nil
	end
	local targetsPlayer = Plain(ns.SafeReadable(UnitIsUnit, unit .. "target", "player"))
	local acted = GetTime() - lastAction
	local rec = {
		mobLevel = info.level,
		playerLevel = info.playerLevel,
		radius = before.radius,
		lowerBound = before.lowerBound or nil,
		minRange = before.minRange,
		maxRange = before.maxRange,
		pullMinRange = pullMin,
		pullMaxRange = pullMax,
		auraModifier = before.auraModifier ~= 0 and before.auraModifier or nil,
		key = info.key,
		source = before.source,
		classified = before.state,
		targetsPlayer = targetsPlayer,
		actedAgo = acted < math.huge and math.floor(acted * 10 + 0.5) / 10 or nil,
		classification = ns.SafeReadable(UnitClassification, unit),
		stealthed = ns.SafeReadable(IsStealthed),
		zone = ns.SafeReadable(GetRealZoneText),
		at = time and time() or nil,
	}
	local log = A.Log()
	local reason = A.Reason(rec)
	log.counts.seen = (log.counts.seen or 0) + 1
	log.counts[reason] = (log.counts[reason] or 0) + 1
	if reason == "used" then
		local pulls = log.pulls
		pulls[#pulls + 1] = rec
		while #pulls > MAX_PULLS do
			table.remove(pulls, 1)
		end
	end
	return rec
end

-- Proximity aggro: the mob went for you and you hadn't just attacked or cast.
function A.IsProximityPull(rec)
	return rec.targetsPlayer == true and (rec.actedAgo == nil or rec.actedAgo >= A.ACTION_GRACE)
end

---------------------------------------------------------------------------
-- Learning
---------------------------------------------------------------------------

-- Pulls needed before your measured average replaces the default for mobs you haven't met.
A.GLOBAL_MIN_PULLS = 3
-- Brackets wider than this say too little to learn from.
A.MAX_WIDTH = 15

local byKey = {} -- key -> list of {lo, hi}
local all = {}
-- Fits are asked for on every nameplate five times a second, so they're kept until a pull changes them.
local fitByKey, fitAll = {}, nil

-- A pull's interval on the level-neutral base scale, or nil when it can't teach anything: it needs
-- proximity aggro, no stealth, a known level, both range readings with an upper end, and distances
-- away from the 5- and 45-yard limits where the formula is clamped.
function A.Interval(rec)
	if not A.IsProximityPull(rec) or rec.stealthed or rec.lowerBound then
		return nil
	end
	if type(rec.mobLevel) ~= "number" or type(rec.playerLevel) ~= "number" or rec.mobLevel <= 0 then
		return nil
	end
	local lo, hi = rec.minRange, rec.maxRange
	if rec.pullMinRange ~= nil then
		lo = lo and math.min(lo, rec.pullMinRange) or rec.pullMinRange
	end
	if rec.pullMaxRange ~= nil and hi ~= nil then
		hi = math.max(hi, rec.pullMaxRange)
	end
	if lo == nil or hi == nil or hi < lo or hi - lo > A.MAX_WIDTH then
		return nil
	end
	if lo <= A.MIN_RADIUS or hi >= A.MAX_RADIUS then
		return nil
	end
	local shift = (rec.mobLevel - rec.playerLevel) + (rec.auraModifier or 0)
	return lo - shift, hi - shift
end

-- Best single value for a set of intervals: the middle of their overlap when they agree, otherwise
-- the median of their midpoints, so one odd pull can't drag the estimate.
function A.Fit(intervals)
	local n = #intervals
	if n == 0 then
		return nil
	end
	local lo, hi = -math.huge, math.huge
	for _, iv in ipairs(intervals) do
		lo = math.max(lo, iv[1])
		hi = math.min(hi, iv[2])
	end
	if lo <= hi then
		return (lo + hi) / 2, n
	end
	local mids = {}
	for i, iv in ipairs(intervals) do
		mids[i] = (iv[1] + iv[2]) / 2
	end
	table.sort(mids)
	if n % 2 == 1 then
		return mids[(n + 1) / 2], n
	end
	return (mids[n / 2] + mids[n / 2 + 1]) / 2, n
end

-- Why a pull can or can't be learned from: "used", or "youFirst" (you cast or swung just before),
-- "notYou" (it went for someone else), "stealthed", "tooClose" (inside the 5-yard floor) or "unclear"
-- (no usable bracket, a ?? mob, or the 45-yard cap).
function A.Reason(rec)
	if A.Interval(rec) then
		return "used"
	end
	if rec.targetsPlayer ~= true then
		return "notYou"
	end
	if rec.actedAgo ~= nil and rec.actedAgo < A.ACTION_GRACE then
		return "youFirst"
	end
	if rec.stealthed then
		return "stealthed"
	end
	local lo = rec.pullMinRange or rec.minRange
	if lo ~= nil and lo <= A.MIN_RADIUS then
		return "tooClose"
	end
	return "unclear"
end

function A.Learn(rec)
	local lo, hi = A.Interval(rec)
	if not lo then
		return false
	end
	local iv = { lo, hi }
	all[#all + 1] = iv
	fitAll = nil
	if rec.key then
		byKey[rec.key] = byKey[rec.key] or {}
		local list = byKey[rec.key]
		list[#list + 1] = iv
		fitByKey[rec.key] = nil
	end
	return true
end

-- Logs from before LOG_VERSION 2 kept every pull. Count those by reason and keep the learnable ones.
local function Migrate(log)
	if log.version == LOG_VERSION then
		return
	end
	local keep, counts = {}, {}
	for _, rec in ipairs(log.pulls) do
		local reason = A.Reason(rec)
		counts.seen = (counts.seen or 0) + 1
		counts[reason] = (counts[reason] or 0) + 1
		if reason == "used" then
			keep[#keep + 1] = rec
		end
	end
	log.pulls, log.counts, log.version = keep, counts, LOG_VERSION
end

function A.Rebuild()
	wipe(byKey)
	wipe(all)
	wipe(fitByKey)
	fitAll = nil
	local log = A.Log()
	Migrate(log)
	for _, rec in ipairs(log.pulls) do
		A.Learn(rec)
	end
end

function A.Forget()
	local log = A.Log()
	wipe(log.pulls)
	wipe(log.counts)
	A.Rebuild()
end

-- Level-neutral base radius for a mob and where it came from: "mob" (this NPC's own pulls), "you"
-- (your average over every pull) or "default".
function A.BaseFor(key)
	local list = key and byKey[key]
	if list then
		local base = fitByKey[key]
		if not base then
			base = A.Fit(list)
			fitByKey[key] = base
		end
		return base, "mob", #list
	end
	if #all >= A.GLOBAL_MIN_PULLS then
		fitAll = fitAll or A.Fit(all)
		return fitAll, "you", #all
	end
	return A.BASE_RADIUS, "default", 0
end

function A.Stats()
	local mobs = 0
	for _ in pairs(byKey) do
		mobs = mobs + 1
	end
	local base = A.Fit(all)
	return { usable = #all, mobs = mobs, base = base, logged = A.Log().counts.seen or 0 }
end

---------------------------------------------------------------------------
-- Estimates
---------------------------------------------------------------------------

-- Radius in whole yards from a level-neutral base and the mob's detection-range auras.
-- Returns radius, isLowerBound (true for "??" mobs, at least ten levels above you), or nil.
function A.EstimateRadius(mobLevel, playerLevel, base, modifier)
	if ns.IsSecret(mobLevel) or ns.IsSecret(playerLevel) then
		return nil
	end
	if type(mobLevel) ~= "number" or type(playerLevel) ~= "number" then
		return nil
	end
	base = base or A.BASE_RADIUS
	modifier = modifier or 0
	if mobLevel <= 0 then
		return math.max(A.MIN_RADIUS, math.floor(base + 10 + modifier + 0.5)), true
	end
	local r = base + (mobLevel - playerLevel) + modifier
	if r < A.MIN_RADIUS then
		r = A.MIN_RADIUS
	elseif r > A.MAX_RADIUS then
		r = A.MAX_RADIUS
	end
	return math.floor(r + 0.5), false
end

-- Where you stand relative to the radius, given the bracket [minRange, maxRange] the client can prove.
-- maxRange is nil when the mob is beyond every range check.
function A.Classify(radius, minRange, maxRange, margin)
	if radius == nil or minRange == nil then
		return "unknown"
	end
	if maxRange ~= nil and maxRange <= radius then
		return "inside"
	end
	if minRange < radius then
		return "edge"
	end
	if minRange < radius + (margin or 0) then
		return "near"
	end
	return "safe"
end

-- Total detection-range change from Soothe auras on the unit; 0 when none or the auras are secret.
function A.AuraModifier(unit)
	local api = C_UnitAuras
	if not (api and api.GetUnitAuraBySpellID) then
		return 0
	end
	local total = 0
	for spellID, yards in pairs(A.DETECT_RANGE_AURAS) do
		local ok, aura = pcall(api.GetUnitAuraBySpellID, unit, spellID)
		if ok and aura ~= nil then
			if ns.IsSecret(aura) then
				A.CountSecret("aura")
				return 0
			end
			total = total + yards
		end
	end
	return total
end

-- Identity for learning: "npc:<id>" from the GUID when readable, else "name:<name>", else nil.
function A.UnitKey(unit)
	local guid = UnitGUID(unit)
	if ns.IsSecret(guid) then
		A.CountSecret("guid")
	elseif type(guid) == "string" then
		local kind, _, _, _, _, npcID = strsplit("-", guid)
		if (kind == "Creature" or kind == "Vehicle") and npcID then
			return "npc:" .. npcID
		end
	end
	local name = UnitName(unit)
	if ns.IsSecret(name) then
		A.CountSecret("name")
		return nil
	end
	if type(name) == "string" and name ~= "" then
		return "name:" .. name
	end
	return nil
end

-- Reads one unit. Returns info for a hostile NPC worth a marker, or nil, reason.
-- Every value is checked for secrecy before Lua compares it.
function A.ReadUnit(unit, cfg)
	local function secret(field, v)
		if ns.IsSecret(v) then
			A.CountSecret(field)
			return true
		end
		return false
	end
	local exists = UnitExists(unit)
	if secret("exists", exists) or not exists then
		return nil, "gone"
	end
	local canAttack = UnitCanAttack("player", unit)
	if secret("canAttack", canAttack) then
		return nil, "secret"
	end
	if not canAttack then
		return nil, "friendly"
	end
	local isPlayer = UnitIsPlayer(unit)
	if secret("isPlayer", isPlayer) then
		return nil, "secret"
	end
	if isPlayer then
		return nil, "player"
	end
	local dead = UnitIsDead(unit)
	if secret("dead", dead) then
		return nil, "secret"
	end
	if dead then
		return nil, "dead"
	end
	local reaction = UnitReaction(unit, "player")
	if secret("reaction", reaction) then
		return nil, "secret"
	end
	if reaction == nil or reaction > 4 then
		return nil, "friendly"
	end
	local neutral = reaction == 4
	if neutral and not (cfg and cfg.includeNeutral) then
		return nil, "neutral"
	end
	local inCombat = UnitAffectingCombat(unit)
	if secret("combat", inCombat) then
		return nil, "secret"
	end
	local level, playerLevel = UnitLevel(unit), UnitLevel("player")
	if secret("level", level) or secret("playerLevel", playerLevel) then
		return nil, "secret"
	end
	local key = A.UnitKey(unit)
	local modifier = A.AuraModifier(unit)
	local base, source = A.BaseFor(key)
	local radius, lowerBound = A.EstimateRadius(level, playerLevel, base, modifier)
	if not radius then
		return nil, "nolevel"
	end
	return {
		level = level,
		playerLevel = playerLevel,
		radius = radius,
		lowerBound = lowerBound,
		neutral = neutral,
		inCombat = inCombat and true or false,
		key = key,
		auraModifier = modifier,
		source = source, -- "mob", "you" or "default"
	}
end

-- Range bracket from LibRangeCheck-3.0: minRange, maxRange, or nil without a reading.
function A.GetRange(unit)
	local rc = A.rangeCheck
	if not rc then
		return nil
	end
	local ok, minRange, maxRange = pcall(rc.GetRange, rc, unit)
	if not ok then
		return nil
	end
	if ns.IsSecret(minRange) or ns.IsSecret(maxRange) then
		A.CountSecret("range")
		return nil
	end
	return minRange, maxRange
end

-- "16y", "16y*" (measured from this mob's pulls), "24y+" ("??" mob), with the bracket appended if asked.
function A.Label(info, minRange, maxRange, cfg)
	if not cfg.showText then
		return ""
	end
	local text = (info.lowerBound and "%dy+" or "%dy"):format(info.radius) .. (info.source == "mob" and "*" or "")
	if cfg.showDistance and minRange then
		if maxRange then
			text = text .. (" %d-%d"):format(minRange, maxRange)
		else
			text = text .. (" %d+"):format(minRange)
		end
	end
	return text
end

-- Lines for /fd pulls: what was logged, what was learned and what the client hid.
function A.Summary()
	local L = ns.L
	local log = A.Log()
	local out = {}
	local proximity, held, tooSmall, unclear = 0, 0, 0, 0
	for _, rec in ipairs(log.pulls) do
		proximity = proximity + 1
		if rec.minRange and rec.minRange >= rec.radius then
			tooSmall = tooSmall + 1
		elseif rec.maxRange and rec.maxRange <= rec.radius then
			held = held + 1
		else
			unclear = unclear + 1
		end
	end
	local c = log.counts
	out[#out + 1] = L["%d pulls seen, %d of them usable (the mob came for you on its own)."]:format(c.seen or 0, proximity)
	if (c.seen or 0) > proximity then
		out[#out + 1] = L["Not usable: %d you attacked first, %d went for someone else, %d too close to tell, %d other."]:format(
			c.youFirst or 0, c.notYou or 0, c.tooClose or 0, (c.stealthed or 0) + (c.unclear or 0))
	end
	if proximity > 0 then
		out[#out + 1] = L["Estimate held: %d. Pulled from outside it: %d. Bracket too wide to tell: %d."]:format(
			held,
			tooSmall,
			unclear
		)
	end
	local s = A.Stats()
	if s.usable > 0 then
		out[#out + 1] = L["Learned from %d pulls across %d mobs: your measured base is %.1f yards at equal level."]:format(
			s.usable,
			s.mobs,
			s.base
		)
		if s.usable < A.GLOBAL_MIN_PULLS then
			out[#out + 1] = L["Mobs you haven't met switch to it after %d pulls."]:format(A.GLOBAL_MIN_PULLS)
		end
	else
		out[#out + 1] = L["Nothing learned yet: estimates use the %d-yard default."]:format(A.BASE_RADIUS)
	end
	local r = log.readings
	out[#out + 1] = L["Range readings: %d ok, %d missing out of combat, %d missing in combat."]:format(
		r.ranged or 0,
		r.noRange or 0,
		r.noRangeInCombat or 0
	)
	local secrets = {}
	for field, n in pairs(log.secret) do
		secrets[#secrets + 1] = field .. "=" .. n
	end
	table.sort(secrets)
	out[#out + 1] = L["Secret values seen:"] .. " " .. (#secrets > 0 and table.concat(secrets, ", ") or L["none"])
	return out
end
