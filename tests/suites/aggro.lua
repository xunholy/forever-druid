-- Aggro radius: the maths, nameplate markers, learning from pulls, threat, Prowl.
-- Run through tests/run.lua, which provides check, section, noErrors, fresh, login and labels.

---------------------------------------------------------------------------
-- Aggro radius on nameplates
---------------------------------------------------------------------------

local function mob(level, range, extra)
	local m = { canAttack = true, isPlayer = false, dead = false, reaction = 2, combat = false, level = level, range = range }
	for k, v in pairs(extra or {}) do
		m[k] = v
	end
	return m
end
local function colour(marker, name, ns)
	local c, v = ns.aggro.colors[name], marker and rawget(marker.dot, "_vertex")
	return v ~= nil and v[1] == c[1] and v[2] == c[2] and v[3] == c[3]
end

do
	local W, ns = fresh()
	section("aggro radius: maths")
	local A = ns.aggro
	local cases = {
		{ 40, 40, 14, "same level: 14 yards" }, { 45, 40, 19, "5 above: 19" }, { 36, 40, 10, "4 below: 10" },
		{ 10, 40, 5, "far below: floor of 5" }, { 75, 40, 45, "far above: cap of 45" },
	}
	for _, c in ipairs(cases) do
		check(A.EstimateRadius(c[1], c[2]) == c[3], c[4])
	end
	local r, lower = A.EstimateRadius(-1, 40)
	check(r == 24 and lower, "?? mob: at least 24")
	-- The client's secrets report the type of the value they hide, so a type() check can't stand in for
	-- the secrecy guard. Pretend so here (the stub's secrets are tables).
	local realType = type
	type = function(v) -- luacheck: ignore 121
		return W.IsSecret(v) and "number" or realType(v)
	end
	local ok = pcall(A.EstimateRadius, W.Secret(), 40)
	check(ok and A.EstimateRadius(W.Secret(), 40) == nil, "secret level: no estimate, no error")
	type = realType -- luacheck: ignore 121
	check(A.EstimateRadius(40, 40, 20, -10) == 10, "Soothe takes 10 yards off")
	check(A.Classify(22, 15, 20, 10) == "inside" and A.Classify(22, 20, 25, 10) == "edge"
		and A.Classify(22, 25, 30, 10) == "near" and A.Classify(22, 35, 40, 10) == "safe"
		and A.Classify(22, 40, nil, 10) == "safe" and A.Classify(22, nil, nil, 10) == "unknown",
		"inside / edge / near / safe / unknown from the range bracket")
	check(A.Fit({ { 18, 28 }, { 20, 25 }, { 22, 30 } }) == 23.5, "overlapping pulls: middle of the overlap")
	check(A.Fit({ { 10, 12 }, { 20, 25 }, { 21, 24 } }) == 22.5, "a disagreeing pull: median of midpoints")
	local rec = { targetsPlayer = true, mobLevel = 42, playerLevel = 40, minRange = 25, maxRange = 30,
		pullMinRange = 20, pullMaxRange = 25 }
	local lo, hi = A.Interval(rec)
	check(lo == 18 and hi == 28, "pull spanning 20-30 yards on a +2 mob: base 18-28")
	rec.stealthed = true
	check(A.Interval(rec) == nil, "stealthed (Prowl) pulls aren't learned")
	rec.stealthed, rec.actedAgo = nil, 0.5
	check(A.Interval(rec) == nil, "pulls right after you acted aren't learned")
end

do
	local W, ns = fresh()
	section("aggro radius: markers")
	login(W)
	check(ns.modules.aggroradius.enabled, "on by default")
	W.AddPlate("nameplate1", mob(42, { 25, 30 }))
	local m = W.MarkerOn("nameplate1")
	check(m and m:IsShown() and m.text:GetText() == "16y", "hostile mob two levels up: 16y")
	check(colour(m, "near", ns), "25-30 yards from a 16-yard radius is yellow")
	W.state.plates.nameplate1.range = { 15, 20 }
	W.Advance(0.25)
	check(colour(m, "edge", ns), "15-20 yards is orange")
	W.state.plates.nameplate1.range = { 10, 15 }
	W.Advance(0.25)
	check(colour(m, "inside", ns), "10-15 yards is red")
	W.state.plates.nameplate1.range = { 40, nil }
	W.Advance(0.25)
	check(colour(m, "safe", ns), "40+ yards is green")
	W.state.plates.nameplate1.range = nil
	W.Advance(0.25)
	check(m:IsShown() and colour(m, "unknown", ns), "no reading: grey, still shown")

	W.AddPlate("nameplate2", mob(40, { 10, 15 }, { canAttack = false, reaction = 5 }))
	W.AddPlate("nameplate3", mob(40, { 10, 15 }, { isPlayer = true }))
	W.AddPlate("nameplate4", mob(40, { 10, 15 }, { reaction = 4 }))
	W.AddPlate("nameplate5", mob(40, { 10, 15 }, { combat = true }))
	local hidden = true
	for i = 2, 5 do
		local f = W.MarkerOn("nameplate" .. i)
		hidden = hidden and (f == nil or not f:IsShown())
	end
	check(hidden, "no marker on friendly NPCs, enemy players, neutral mobs or mobs already fighting")
	W.AddPlate("nameplate6", mob(40, { 25, 30 }, { auras = { [9901] = true } }))
	check(W.MarkerOn("nameplate6").text:GetText() == "5y", "Soothe Animal on the mob: 10 yards off, down to the 5-yard floor")
	local realType = type
	type = function(v) -- luacheck: ignore 121 (secrets report the hidden value's type, as in the client)
		return W.IsSecret(v) and "number" or realType(v)
	end
	W.AddPlate("nameplate7", mob(W.Secret(), { 25, 30 }, { npcID = 9, name = W.Secret(), guid = W.Secret() }))
	local f7 = W.MarkerOn("nameplate7")
	check(f7 == nil or not f7:IsShown(), "secret level: hidden, no error")
	W.Advance(1)
	type = realType -- luacheck: ignore 121
	noErrors(W, "no errors with secret values on plates")

	ns.SetModuleEnabled("aggroradius", false)
	check(not m:IsShown(), "turning the part off hides every marker")
	W.Advance(0.5)
	check(not m:IsShown(), "and they stay hidden")
	ns.SetModuleEnabled("aggroradius", true)
	check(m:IsShown(), "turning it back on brings them back")
	noErrors(W, "no Lua errors")
end

do
	local W, ns = fresh()
	section("aggro radius: learning from pulls")
	login(W)
	local function pull(token, npcID, level, before, during)
		W.AddPlate(token, mob(level, before, { npcID = npcID }))
		W.Advance(0.25)
		local p = W.state.plates[token]
		p.range, p.combat, p.targetsPlayer = during, true, true
		W.Advance(0.25)
		W.RemovePlate(token)
	end
	pull("nameplate1", 1501, 42, { 25, 30 }, { 20, 25 })
	local log = ForeverDruidProbe.aggro
	check(log and #log.pulls == 1 and log.pulls[1].key == "npc:1501", "pull logged in ForeverDruidProbe.aggro by NPC ID")
	W.AddPlate("nameplate2", mob(42, { 35, 40 }, { npcID = 1501 }))
	check(W.MarkerOn("nameplate2").text:GetText() == "25y*", "same NPC again: measured 23 + 2 levels, marked *")
	W.AddPlate("nameplate3", mob(40, { 35, 40 }, { npcID = 9999 }))
	check(W.MarkerOn("nameplate3").text:GetText() == "14y", "an NPC you haven't met: the 14-yard default")
	pull("nameplate4", 2001, 40, { 25, 30 }, { 20, 25 })
	W.Advance(0.25)
	check(W.MarkerOn("nameplate3").text:GetText() == "14y", "two pulls aren't enough to replace the default")
	for i = 2, 4 do
		pull("nameplate4", 2000 + i, 40, { 25, 30 }, { 20, 25 })
	end
	W.Advance(0.25)
	check(W.MarkerOn("nameplate3").text:GetText() == "24y", "from three pulls on, unmet NPCs use your measured base")

	-- Casting first means you pulled it: logged, not learned.
	W.AddPlate("nameplate5", mob(40, { 25, 30 }, { npcID = 3000 }))
	W.Advance(0.25)
	W.Fire("UNIT_SPELLCAST_SENT", "player")
	W.state.plates.nameplate5.combat, W.state.plates.nameplate5.targetsPlayer = true, true
	W.Advance(0.25)
	check(#log.pulls == 5 and log.counts.youFirst == 1 and log.counts.seen == 6
		and select(2, ns.aggro.BaseFor("npc:3000")) ~= "mob", "a pull right after your cast is counted, not stored or learned")
	-- A week of pulling mobs yourself can't push the learned pulls out of the log.
	for _ = 1, 2500 do
		ns.aggro.RecordPull("nameplate5", { radius = 14, minRange = 25, maxRange = 30 },
			{ level = 40, playerLevel = 40, key = "npc:3000" }, 20, 25)
	end
	check(#log.pulls == 5 and log.counts.seen == 2506 and select(2, ns.aggro.BaseFor("npc:1501")) == "mob",
		"2,500 pulls you started: counted, and every learned pull is still there")
	wipe(log.counts)
	log.counts.seen, log.counts.used, log.counts.youFirst = 6, 5, 1

	W.printed = {}
	W.Slash("pulls")
	local said = table.concat(W.printed, "\n")
	check(said:find("6 pulls seen, 5 of them usable", 1, true) ~= nil and said:find("1 you attacked first", 1, true) ~= nil,
		"/fd pulls counts pulls and says why the rest weren't usable")
	check(said:find("Learned from 5 pulls across 5 mobs", 1, true) ~= nil, "/fd pulls shows what was learned")
	check(ns.ModuleStatus("aggroradius"):find("5 mobs measured", 1, true) ~= nil, "status line in At a glance")

	local saved = ForeverDruidProbe
	local W2, ns2 = fresh()
	ForeverDruidProbe = saved
	login(W2)
	local base, source = ns2.aggro.BaseFor("npc:1501")
	check(source == "mob" and base == 23, "learned radii come back after a reload")
	W2.Slash("pulls reset")
	check(#ForeverDruidProbe.aggro.pulls == 0 and select(2, ns2.aggro.BaseFor("npc:1501")) == "default",
		"/fd pulls reset forgets them")

	local ok = W2.ShowOptionsPanel()
	check(ok, "settings pages still build")
	W2.Slash("radius")
	check(W2.openedCategory ~= nil, "/fd radius opens the aggro radius settings")
	noErrors(W2, "no Lua errors")

	-- A log saved by 0.6.0 kept every pull: on login the junk is counted and dropped, the rest kept.
	local W3, ns3 = fresh()
	local good = { targetsPlayer = true, actedAgo = 12, mobLevel = 40, playerLevel = 40, minRange = 10, maxRange = 15,
		pullMinRange = 10, pullMaxRange = 15, radius = 20, key = "npc:7" }
	local old = { pulls = { good }, secret = {}, readings = {} }
	for i = 1, 30 do
		old.pulls[#old.pulls + 1] = { targetsPlayer = i % 3 ~= 0, actedAgo = 0.1, mobLevel = 40, playerLevel = 40,
			minRange = 20, maxRange = 25, pullMinRange = 20, pullMaxRange = 25, radius = 20, key = "npc:8" }
	end
	ForeverDruidProbe = { aggro = old }
	login(W3)
	local migrated = ForeverDruidProbe.aggro
	check(#migrated.pulls == 1 and migrated.pulls[1] == good and migrated.counts.seen == 31
		and migrated.counts.youFirst == 20 and migrated.counts.notYou == 10 and migrated.version == 2,
		"an old log is pruned to its learnable pulls, with the rest counted by reason")
	check(select(2, ns3.aggro.BaseFor("npc:7")) == "mob" and ns3.aggro.BaseFor("npc:7") == 12.5, "and what it had learned survives")
	noErrors(W3, "no errors migrating")
end

do
	local W, ns = fresh()
	section("aggro radius: threat once a mob is fighting, fading while you Prowl")
	login(W)
	local function text(token)
		local m = W.MarkerOn(token)
		return m and m:IsShown() and m.text:GetText() or nil
	end
	local function fight(token, extra)
		local m = mob(40, { 0, 5 }, extra)
		m.combat = true
		W.AddPlate(token, m)
		W.Advance(0.25)
	end
	-- Solo: every mob is on you, so nothing is shown.
	fight("nameplate1", { threat = 3, threatPct = 100, lead = 130 })
	check(text("nameplate1") == nil, "solo: no threat marker (it would always say yours)")
	-- In a group, in Bear Form (form 2): the tank's view.
	W.state.party = { party1 = { name = "Healer", class = "Priest" } }
	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.25)
	local m1 = W.MarkerOn("nameplate1")
	check(text("nameplate1") == "130%" and colour(m1, "safe", ns), "tanking it safely: green, with your lead (130%)")
	fight("nameplate2", { threat = 2, threatPct = 100, lead = 104 })
	check(text("nameplate2") == "104%" and colour(W.MarkerOn("nameplate2"), "near", ns), "someone's catching up: yellow")
	fight("nameplate3", { threat = 0, threatPct = 62 })
	check(text("nameplate3") == "62%" and colour(W.MarkerOn("nameplate3"), "inside", ns),
		"it's on someone else: red, with how far behind you are")
	-- The same mobs seen from Cat Form: the colours run the other way.
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.25)
	check(colour(m1, "inside", ns) and colour(W.MarkerOn("nameplate3"), "safe", ns),
		"out of Bear Form: red means it's on you, green means it isn't")
	-- Forever hides it: nothing shown, no errors, and the probe counts it.
	local realType = type
	type = function(v) -- luacheck: ignore 121
		return W.IsSecret(v) and "number" or realType(v)
	end
	fight("nameplate4", { threat = W.Secret() })
	local hidden4 = text("nameplate4") == nil
	fight("nameplate5", { threat = 3, threatPct = W.Secret() })
	local shown5 = text("nameplate5")
	type = realType -- luacheck: ignore 121
	check(hidden4 and ForeverDruidProbe.aggro.secret.threat >= 1, "threat hidden by the game: no marker, counted for the probe")
	check(shown5 == "" and colour(W.MarkerOn("nameplate5"), "inside", ns), "percentage hidden but status readable: colour only")
	-- Not on its threat table at all (it's fighting someone and ignoring you): nothing.
	fight("nameplate6")
	check(text("nameplate6") == nil, "a mob you have no threat on: no marker")
	ns.db.modules.aggroradius.threat = false
	W.Advance(0.25)
	check(text("nameplate1") == nil, "threat display can be turned off")
	ns.db.modules.aggroradius.threat = true

	-- Prowl: calm mobs' markers fade and the warning sound stays quiet.
	ns.db.modules.aggroradius.sound = true
	W.AddPlate("nameplate7", mob(40, { 30, 35 }))
	W.Advance(0.25)
	local m7 = W.MarkerOn("nameplate7")
	check(m7:GetAlpha() == 1, "not prowling: full strength")
	W.state.stealthed = true
	W.sounds = {}
	W.state.plates.nameplate7.range = { 5, 10 }
	W.Advance(0.25)
	check(m7:IsShown() and m7:GetAlpha() < 1 and #W.sounds == 0, "prowling: marker fades and no sound as you close in")
	W.state.stealthed = false
	W.Advance(0.25)
	check(m7:GetAlpha() == 1, "out of Prowl: back to full strength")
	noErrors(W, "no Lua errors")
end

do
	local W, ns = fresh(function(W0)
		W0.state.class = "WARLOCK"
	end)
	section("aggro radius: druids only")
	login(W)
	W.AddPlate("nameplate1", mob(40, { 25, 30 }))
	local m = W.MarkerOn("nameplate1")
	check(not ns.modules.aggroradius.enabled and (m == nil or not m:IsShown()), "no markers on other classes")
	noErrors(W, "no Lua errors")
end
