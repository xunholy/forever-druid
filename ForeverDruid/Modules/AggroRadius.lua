-- Aggro radius: a coloured dot and the estimated aggro radius on each enemy nameplate, refreshed five
-- times a second. Red: you're inside the radius; orange: you might be; yellow: within the margin;
-- green: clear; grey: no range reading. The maths, the pull log and learning are in AggroData.lua.
--
-- Markers are our own frames parented to the nameplate, so they work with Blizzard's plates and with
-- Plater, never touch the plate's fields, and aren't part of the HUD (they stay up while mounted).

local _, ns = ...
local A = ns.aggro

local TICK = 0.2
local MAX_PLATES = 40
local SOUND_THROTTLE = 3
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local module = ns.RegisterModule("aggroradius", {})

local markers = setmetatable({}, { __mode = "k" }) -- nameplate frame -> marker
local unitMarker = {} -- "nameplate3" -> the marker on that unit's plate
local state = {} -- "nameplate3" -> last reading
local ticker
local lastSound = -math.huge

local function Config()
	return ns.ModuleConfig("aggroradius")
end

local function IsPlateUnit(unit)
	return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function PlayerInCombat()
	local v = ns.SafeReadable(UnitAffectingCombat, "player")
	if v == nil then
		return ns.InCombat()
	end
	return v and true or false
end

local function CreateMarker(plate)
	local m = CreateFrame("Frame", nil, plate)
	m:SetSize(12, 12)
	m:SetPoint("RIGHT", plate, "LEFT", -2, 0)
	m:SetFrameLevel((plate:GetFrameLevel() or 0) + 10)
	local dot = m:CreateTexture(nil, "OVERLAY")
	dot:SetTexture("Interface\\Buttons\\WHITE8x8")
	dot:SetSize(10, 10)
	dot:SetPoint("RIGHT", m, "RIGHT")
	local mask = m:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(dot)
	dot:AddMaskTexture(mask)
	local text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("RIGHT", dot, "LEFT", -2, 0)
	m.dot, m.text = dot, text
	m:SetScale(Config().scale or 1)
	m:Hide()
	return m
end

local function MarkerFor(unit)
	local m = unitMarker[unit]
	if m then
		return m
	end
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
	if not plate then
		return nil
	end
	m = markers[plate]
	if not m then
		m = CreateMarker(plate)
		markers[plate] = m
	end
	unitMarker[unit] = m
	return m
end

local function HideUnit(unit)
	local m = unitMarker[unit]
	if m then
		m:Hide()
	end
end

local function Show(m, cls, text)
	local c = A.colors[cls] or A.colors.unknown
	m.dot:SetVertexColor(c[1], c[2], c[3])
	m.text:SetText(text)
	m.text:SetTextColor(c[1], c[2], c[3])
	m.state = cls
	m:Show()
end

function module.UpdateUnit(unit, now, playerInCombat)
	local cfg = Config()
	local info = A.ReadUnit(unit, cfg)
	local prev = state[unit]

	if info and info.inCombat then
		-- The mob just entered combat. If it was calm a moment ago and so were you, log the pull.
		if prev and not prev.inCombat and not prev.playerInCombat then
			local pullMin, pullMax = A.GetRange(unit)
			local rec = A.RecordPull(unit, prev, info, pullMin, pullMax)
			if rec then
				A.Learn(rec)
			end
		end
		state[unit] = { inCombat = true }
		HideUnit(unit)
		return
	end
	if not info then
		state[unit] = nil
		HideUnit(unit)
		return
	end

	local minRange, maxRange = A.GetRange(unit)
	A.CountReading(minRange ~= nil, playerInCombat)
	local cls = A.Classify(info.radius, minRange, maxRange, cfg.margin)
	local m = MarkerFor(unit)
	if m then
		Show(m, cls, A.Label(info, minRange, maxRange, cfg))
	end

	if cfg.sound and not playerInCombat and prev and now - lastSound >= SOUND_THROTTLE then
		local was = A.SEVERITY[prev.state or "unknown"]
		if A.SEVERITY[cls] >= A.SEVERITY.edge and was < A.SEVERITY.edge then
			PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
			lastSound = now
		end
	end

	state[unit] = {
		inCombat = false,
		radius = info.radius,
		lowerBound = info.lowerBound,
		auraModifier = info.auraModifier,
		source = info.source,
		minRange = minRange,
		maxRange = maxRange,
		state = cls,
		playerInCombat = playerInCombat,
	}
end

function module.Tick()
	if not module.enabled then
		return
	end
	local now, playerInCombat = GetTime(), PlayerInCombat()
	for unit in pairs(unitMarker) do
		module.UpdateUnit(unit, now, playerInCombat)
	end
end

-- Picks up plates that already exist (after /reload or turning the part on).
local function SeedPlates()
	for i = 1, MAX_PLATES do
		local unit = "nameplate" .. i
		local exists = ns.SafeReadable(UnitExists, unit)
		if exists then
			MarkerFor(unit)
		end
	end
end

local function HideAll()
	for _, m in pairs(markers) do
		m:Hide()
	end
end

function module:Init()
	A.rangeCheck = LibStub and LibStub("LibRangeCheck-3.0", true) or nil
	if not A.rangeCheck then
		ns.Print(ns.L["Aggro radius: LibRangeCheck-3.0 didn't load, so distances are unavailable."])
	end
	A.Rebuild()
end

function module:Enable()
	if ticker then
		ticker:Cancel()
	end
	SeedPlates()
	ticker = C_Timer.NewTicker(TICK, module.Tick)
	module.Tick()
end

function module:Disable()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	HideAll()
	wipe(state)
end

function module:Refresh()
	local scale = Config().scale or 1
	for _, m in pairs(markers) do
		m:SetScale(scale)
	end
	module.Tick()
end

ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit)
	if not IsPlateUnit(unit) then
		return -- the settings preview fires this with a fake token
	end
	unitMarker[unit] = nil -- the token may now belong to a different plate
	state[unit] = nil
	if module.enabled and MarkerFor(unit) then
		module.UpdateUnit(unit, GetTime(), PlayerInCombat())
	end
end)

ns.On("NAME_PLATE_UNIT_REMOVED", function(_, unit)
	if IsPlateUnit(unit) then
		HideUnit(unit)
		unitMarker[unit] = nil
		state[unit] = nil
	end
end)

ns.OnUnit("UNIT_SPELLCAST_SENT", "player", function()
	A.NoteAction()
end)

ns.On("PLAYER_ENTER_COMBAT", function() -- auto-attack switched on
	A.NoteAction()
end)
