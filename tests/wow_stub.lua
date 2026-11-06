-- Minimal WoW Forever API emulation for running ForeverDruid outside the game (Lua 5.4).
--
-- Secret values behave like the client's: comparison, arithmetic, concatenation, indexing and
-- tostring raise errors. Defaults mirror the live probe (1.60.1.70790): player mana/rage/energy are
-- secret even out of combat, maximums and combo points are readable, auras go secret in combat.

local W = { frames = {}, errors = {}, timers = {}, tickers = {}, now = 1000, printed = {}, blocked = {} }

---------------------------------------------------------------------------
-- Secret values
---------------------------------------------------------------------------

local SecretMT = {}
local function boom(op)
	return function()
		error("attempt to " .. op .. " a secret value", 2)
	end
end
for _, mm in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__idiv",
	"__concat", "__len", "__band", "__bor", "__bxor", "__shl", "__shr", "__bnot", "__call" }) do
	SecretMT[mm] = boom(mm:sub(3))
end
SecretMT.__tostring = boom("tostring")
SecretMT.__index = boom("index")
SecretMT.__newindex = boom("assign into")
function W.Secret()
	return setmetatable({}, SecretMT)
end
function W.IsSecret(v)
	return getmetatable(v) == SecretMT
end
_G.issecretvalue = W.IsSecret

---------------------------------------------------------------------------
-- Lua 5.1 / WoW globals
---------------------------------------------------------------------------

unpack = table.unpack
strlower = string.lower
strupper = string.upper
strtrim = function(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
strsplit = function(sep, s, limit)
	local out, start = {}, 1
	while true do
		if limit and #out == limit - 1 then
			out[#out + 1] = s:sub(start)
			break
		end
		local i, j = s:find(sep, start, true)
		if not i then
			out[#out + 1] = s:sub(start)
			break
		end
		out[#out + 1] = s:sub(start, i - 1)
		start = j + 1
	end
	return table.unpack(out)
end
wipe = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(i, ...)))
	end
	W.printed[#W.printed + 1] = table.concat(parts, " ")
end
geterrorhandler = function()
	return function(err)
		W.errors[#W.errors + 1] = tostring(err)
	end
end
GetTime = function()
	return W.now
end
GetLocale = function()
	return "enUS"
end
date = os.date
WOW_PROJECT_CAMELOT = 18
WOW_PROJECT_ID = 18
GetBuildInfo = function()
	return "1.60.1", "70790", "Nov 3 2026", 16001
end

function CreateColor(r, g, b, a)
	return { r = r, g = g, b = b, a = a or 1, GetRGB = function(self)
		return self.r, self.g, self.b
	end }
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local Frame = {}
Frame.__index = function(self, key)
	local method = Frame[key]
	if method ~= nil then
		return method
	end
	return function()
		return nil
	end
end

local function NewObject(kind, parent, template)
	local o = setmetatable({ _kind = kind, _parent = parent, _template = template, _shown = true, _scripts = {},
		_events = {}, _unitEvents = {}, _attributes = {}, _w = 0, _h = 0, _alpha = 1, _scale = 1,
		_points = {}, _values = {} }, Frame)
	W.frames[#W.frames + 1] = o
	return o
end

local function IsProtected(frame)
	if rawget(frame, "_template") == "SecureActionButtonTemplate" then
		return true
	end
	for _, f in ipairs(W.frames) do
		if rawget(f, "_template") == "SecureActionButtonTemplate" then
			local p = rawget(f, "_parent")
			while p do
				if p == frame then
					return true
				end
				p = rawget(p, "_parent")
			end
		end
	end
	return false
end

-- Protected frames (secure buttons and their ancestors) refuse visibility/attribute/position
-- changes during combat lockdown, like the real client.
local function GuardProtected(frame, action)
	if W.state.inCombat and IsProtected(frame) then
		W.blocked[#W.blocked + 1] = action
		error("ADDON_ACTION_BLOCKED: " .. action .. " on a protected frame in combat")
	end
end

function Frame:CreateTexture()
	return NewObject("Texture", self)
end
function Frame:CreateFontString()
	return NewObject("FontString", self)
end
function Frame:SetScript(name, fn)
	self._scripts[name] = fn
end
function Frame:GetScript(name)
	return self._scripts[name]
end
function Frame:RegisterEvent(event)
	if W.unknownEvents and W.unknownEvents[event] then
		error("Attempt to register unknown event \"" .. event .. "\"")
	end
	self._events[event] = true
end
function Frame:RegisterUnitEvent(event, ...)
	if W.unknownEvents and W.unknownEvents[event] then
		error("Attempt to register unknown event \"" .. event .. "\"")
	end
	local units = {}
	for i = 1, select("#", ...) do
		units[(select(i, ...))] = true
	end
	self._unitEvents[event] = units
end
function Frame:UnregisterEvent(event)
	self._events[event] = nil
end
function Frame:Show()
	GuardProtected(self, "Show")
	self._shown = true
end
function Frame:Hide()
	GuardProtected(self, "Hide")
	self._shown = false
end
function Frame:SetShown(v)
	GuardProtected(self, "SetShown")
	self._shown = v and true or false
end
function Frame:IsShown()
	return self._shown
end
function Frame:IsVisible()
	local o = self
	while o do
		if not rawget(o, "_shown") then
			return false
		end
		o = rawget(o, "_parent")
	end
	return true
end
function Frame:SetSize(w, h)
	self._w, self._h = w, h
end
function Frame:SetWidth(w)
	self._w = w
end
function Frame:SetHeight(h)
	self._h = h
end
function Frame:GetWidth()
	return self._w
end
function Frame:GetHeight()
	return self._h
end
function Frame:SetAlpha(a)
	self._alpha = a
end
function Frame:GetAlpha()
	return self._alpha
end
function Frame:SetScale(s)
	GuardProtected(self, "SetScale")
	self._scale = s
end
function Frame:SetPoint(...)
	GuardProtected(self, "SetPoint")
	self._points[#self._points + 1] = { ... }
end
function Frame:ClearAllPoints()
	GuardProtected(self, "ClearAllPoints")
	self._points = {}
end
function Frame:GetPoint()
	local p = self._points[1]
	if not p then
		return nil
	end
	return p[1], p[2], p[3], p[4], p[5]
end
function Frame:StartMoving()
	self._moving = true
end
function Frame:StopMovingOrSizing()
	self._moving = false
end
function Frame:EnableMouse(v)
	GuardProtected(self, "EnableMouse")
	self._mouse = v
end
function Frame:SetAttribute(key, value)
	GuardProtected(self, "SetAttribute")
	self._attributes[key] = value
end
function Frame:GetAttribute(key)
	return self._attributes[key]
end
function Frame:SetText(text)
	if W.IsSecret(text) then
		self._text = "<secret text>"
		return
	end
	self._text = text
end
function Frame:GetText()
	return self._text
end
function Frame:SetFormattedText(fmt, ...)
	for i = 1, select("#", ...) do
		if W.IsSecret((select(i, ...))) then
			self._text = "<secret text>"
			return
		end
	end
	self._text = string.format(fmt, ...)
end
function Frame:SetValue(v)
	self._values.value = v
end
function Frame:SetMinMaxValues(a, b)
	self._values.min, self._values.max = a, b
end
function Frame:SetStatusBarColor(r, g, b)
	self._color = { r, g, b }
end
function Frame:SetTexture(t)
	self._texture = t
end
function Frame:SetChecked(v)
	self._checked = v
end
function Frame:GetChecked()
	return self._checked
end
function Frame:SetCooldownFromDurationObject(duration)
	if type(duration) ~= "table" or not rawget(duration, "_isDuration") then
		error("SetCooldownFromDurationObject: bad duration")
	end
	self._cooldown = duration
end
function Frame:SetCooldownFromExpirationTime(expirationTime, duration)
	self._cooldown = { expirationTime = expirationTime, duration = duration }
end
function Frame:SetCooldown(start, duration)
	self._cooldown = { start = start, duration = duration }
end
function Frame:Clear()
	self._cooldown = nil
end

UIParent = NewObject("Frame")
GameTooltip = NewObject("GameTooltip")

function Frame:GetCenter()
	return rawget(self, "_cx") or 0, rawget(self, "_cy") or 0
end
function Frame:GetEffectiveScale()
	return 1
end

-- A 140px round minimap centred at (1000, 600) in screen coordinates.
Minimap = NewObject("Frame", UIParent)
Minimap._w, Minimap._h, Minimap._cx, Minimap._cy = 140, 140, 1000, 600

function GetCursorPosition()
	return W.cursor and W.cursor[1] or 0, W.cursor and W.cursor[2] or 0
end
function ReloadUI()
	W.reloaded = true
end

-- Blizzard's Menu system: records the description tree a generator builds so tests can walk it
-- and "click" entries.
local Description = {}
Description.__index = Description
local function NewDescription(kind, text, isSelected, onSelect)
	return setmetatable({ kind = kind, text = text, isSelected = isSelected, onSelect = onSelect, children = {} }, Description)
end
function Description:Add(kind, text, isSelected, onSelect)
	local child = NewDescription(kind, text, isSelected, onSelect)
	self.children[#self.children + 1] = child
	return child
end
function Description:CreateTitle(text)
	return self:Add("title", text)
end
function Description:CreateButton(text, onClick)
	return self:Add("button", text, nil, onClick)
end
function Description:CreateCheckbox(text, isSelected, onSelect)
	return self:Add("checkbox", text, isSelected, onSelect)
end
function Description:CreateRadio(text, isSelected, onSelect)
	return self:Add("radio", text, isSelected, onSelect)
end
function Description:CreateDivider()
	return self:Add("divider")
end
-- Finds an entry by a path of texts, e.g. Find("Show", "Mana bar").
function Description:Find(...)
	local node = self
	for i = 1, select("#", ...) do
		local want = select(i, ...)
		local found
		for _, child in ipairs(node.children) do
			if child.text == want or (type(child.text) == "string" and child.text:find(want, 1, true) == 1) then
				found = child
				break
			end
		end
		if not found then
			return nil
		end
		node = found
	end
	return node
end
function Description:Click()
	if self.onSelect then
		self.onSelect()
	end
end
function Description:Selected()
	return self.isSelected and self.isSelected() and true or false
end

MenuUtil = {}
function MenuUtil.CreateContextMenu(owner, generator)
	local root = NewDescription("root")
	generator(owner, root)
	W.lastMenu = root
	return root
end

function CreateFrame(kind, name, parent, template)
	if W.state and W.state.inCombat and template == "SecureActionButtonTemplate" then
		W.blocked[#W.blocked + 1] = "CreateFrame secure"
		error("ADDON_ACTION_BLOCKED: creating a secure frame in combat")
	end
	local f = NewObject(kind, parent, template)
	if name then
		_G[name] = f
	end
	return f
end

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------

C_Timer = {}
function C_Timer.After(delay, fn)
	W.timers[#W.timers + 1] = { at = W.now + (delay or 0), fn = fn }
end
function C_Timer.NewTicker(period, fn)
	local ticker = { period = period, fn = fn, nextAt = W.now + period }
	W.tickers[#W.tickers + 1] = ticker
	return ticker
end

---------------------------------------------------------------------------
-- Game state the tests control
---------------------------------------------------------------------------

W.state = {
	class = "DRUID",
	race = "Skyborne",
	inCombat = false,
	secretPower = true, -- probe: secret even out of combat
	secretAuras = false,
	mounted = false,
	form = 0,
	forms = { 768, 5487, 783 }, -- cat, bear, travel
	power = { [0] = 3000, [1] = 0, [3] = 100, [4] = 0 },
	powerMax = { [0] = 4000, [1] = 100, [3] = 100, [4] = 5 },
	formCost = { [768] = 400, [5487] = 400 },
	auras = {}, -- name -> { spellId=, duration=, expirationTime=, applications= }
	targetExists = false,
	targetHostile = true,
	targetAuras = {}, -- list of { icon, expirationTime, duration, applications, auraInstanceID }
	items = {},
	spellbook = {
		{ 768, "Cat Form" }, { 5487, "Bear Form" }, { 783, "Travel Form" },
		{ 29166, "Innervate" }, { 20484, "Rebirth" }, { 22812, "Barkskin" },
		{ 5217, "Tiger's Fury" }, { 1850, "Dash" }, { 5215, "Prowl" }, { 5229, "Enrage" },
		{ 5232, "Mark of the Wild" }, { 782, "Thorns" }, { 1259705, "Read Leyline" }, { 1259416, "Walk on Air" },
		{ 16689, "Nature's Grasp" },
	},
	extraNames = { [16870] = "Clearcasting", [1259691] = "Attuned", [1126] = "Mark of the Wild", [467] = "Thorns" },
	trees = { { "Balance", 0 }, { "Feral Combat", 21 }, { "Restoration", 5 } },
}
local S = W.state

local SPELL_NAMES = {}
local function RebuildNames()
	wipe(SPELL_NAMES)
	for id, name in pairs(S.extraNames) do
		SPELL_NAMES[id] = name
	end
	for _, entry in ipairs(S.spellbook) do
		SPELL_NAMES[entry[1]] = entry[2]
	end
end
RebuildNames()
W.RebuildNames = RebuildNames

Enum = {
	PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4 },
	SpellBookSpellBank = { Player = 0, Pet = 1 },
	SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
	AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
	LuaCurveType = { Linear = 0, Step = 1 },
}

function UnitClass()
	return "Druid", S.class
end
function UnitRace()
	return "Skyborne", S.race
end
function UnitName()
	return "Starfall"
end
function GetRealmName()
	return "Testrealm"
end
function UnitLevel()
	return 40
end
function InCombatLockdown()
	return S.inCombat
end
function UnitIsDeadOrGhost()
	return false
end
function UnitOnTaxi()
	return false
end
function UnitInVehicle()
	return false
end
function IsMounted()
	return S.mounted
end
function IsShiftKeyDown()
	return S.shift and true or false
end
-- Post-hook like the client: the original runs first and its results are returned unchanged.
function hooksecurefunc(a, b, c)
	local tbl, name, hook = a, b, c
	if type(a) == "string" then
		tbl, name, hook = _G, a, b
	end
	local original = tbl[name]
	rawset(tbl, name, function(...)
		local results = table.pack(original(...))
		hook(...)
		return table.unpack(results, 1, results.n)
	end)
end
function UnitExists()
	return S.targetExists
end
function UnitCanAttack()
	return S.targetHostile
end
function UnitPower(_, powerType)
	powerType = powerType or 0
	if S.secretPower and powerType ~= 4 then
		return W.Secret()
	end
	return S.power[powerType] or 0
end
function UnitPowerMax(_, powerType)
	return S.powerMax[powerType or 0] or 0
end
function GetComboPoints()
	return S.power[4]
end

-- Curves
local CurveMT = {}
CurveMT.__index = CurveMT
function CurveMT:SetType(t)
	self.type = t
end
function CurveMT:AddPoint(x, y)
	self.points[#self.points + 1] = { x, y }
end
C_CurveUtil = {
	CreateCurve = function()
		return setmetatable({ points = {}, kind = "number" }, CurveMT)
	end,
	CreateColorCurve = function()
		return setmetatable({ points = {}, kind = "color" }, CurveMT)
	end,
}
function UnitPowerPercent(_, powerType, _, curve)
	local fraction = (S.power[powerType or 0] or 0) / math.max(1, S.powerMax[powerType or 0] or 1)
	if curve and curve.kind == "color" then
		if S.secretPower then
			local c = CreateColor(0, 0, 0)
			c.r, c.g, c.b = W.Secret(), W.Secret(), W.Secret()
			return c
		end
		return CreateColor(fraction, fraction, 1)
	end
	if S.secretPower then
		return W.Secret()
	end
	return curve and fraction * 100 or fraction
end

function GetShapeshiftForm()
	return S.form
end
function GetNumShapeshiftForms()
	return #S.forms
end
function GetShapeshiftFormInfo(i)
	return 136116, S.form == i, true, S.forms[i]
end

C_Secrets = {
	ShouldUnitPowerBeSecret = function()
		return S.secretPower
	end,
	ShouldUnitPowerMaxBeSecret = function()
		return false
	end,
	ShouldCooldownsBeSecret = function()
		return S.inCombat
	end,
	ShouldAurasBeSecret = function()
		return S.secretAuras
	end,
	ShouldSpellAuraBeSecret = function(id)
		return id ~= 16870 -- pretend only Clearcasting is whitelisted
	end,
}

C_RestrictedActions = {
	GetAddOnRestrictionState = function(kind)
		if kind == 0 and S.inCombat then
			return 2
		end
		return 0
	end,
}

C_Spell = {
	GetSpellName = function(id)
		return SPELL_NAMES[id]
	end,
	GetSpellTexture = function(id)
		return SPELL_NAMES[id] and (100000 + id) or nil
	end,
	GetSpellCooldownDuration = function()
		return { _isDuration = true }
	end,
	GetSpellCooldown = function()
		if S.inCombat then
			return { startTime = W.Secret(), duration = W.Secret() }
		end
		return { startTime = 0, duration = 0 }
	end,
	GetSpellPowerCost = function(id)
		local cost = S.formCost[id]
		return cost and { { type = 0, cost = cost } } or {}
	end,
}

C_SpellBook = {
	GetNumSpellBookSkillLines = function()
		return 1
	end,
	GetSpellBookSkillLineInfo = function()
		return { name = "Druid", itemIndexOffset = 0, numSpellBookItems = #S.spellbook }
	end,
	GetSpellBookItemInfo = function(slot)
		local entry = S.spellbook[slot]
		return entry and { spellID = entry[1], actionID = entry[1], name = entry[2], itemType = 1,
			isPassive = entry.passive or false, isOffSpec = false }
	end,
}

local function AuraFor(name)
	local a = S.auras[name]
	if not a then
		return nil
	end
	return { name = name, spellId = a.spellId or 1, icon = 1000 + (a.spellId or 1), duration = a.duration or 0,
		expirationTime = a.expirationTime or 0, applications = a.applications or 0, auraInstanceID = a.auraInstanceID or 1 }
end

C_UnitAuras = {
	GetAuraDataBySpellName = function(_, name)
		if S.secretAuras then
			error("Auras cannot be accessed when secret")
		end
		return AuraFor(name)
	end,
	GetPlayerAuraBySpellID = function(spellID)
		if S.secretAuras and spellID ~= 16870 then
			error("Auras cannot be accessed when secret")
		end
		for name, a in pairs(S.auras) do
			if a.spellId == spellID then
				return AuraFor(name)
			end
		end
		return nil
	end,
	GetUnitAuras = function(unit, filter, max)
		if unit ~= "target" or not S.targetExists then
			return {}
		end
		local wantHostile = filter:find("HARMFUL", 1, true) ~= nil
		if wantHostile ~= S.targetHostile then
			return {}
		end
		local out = {}
		for i, a in ipairs(S.targetAuras) do
			if max and #out >= max then
				break
			end
			if S.secretAuras then
				out[i] = { icon = W.Secret(), expirationTime = W.Secret(), duration = W.Secret(),
					applications = W.Secret(), auraInstanceID = W.Secret() }
			else
				out[i] = { icon = a.icon, expirationTime = a.expirationTime, duration = a.duration,
					applications = a.applications, auraInstanceID = a.auraInstanceID }
			end
		end
		return out
	end,
	GetAuraApplicationDisplayCount = function(_, id, minCount)
		if W.IsSecret(id) then
			error("secret argument")
		end
		for _, a in ipairs(S.targetAuras) do
			if a.auraInstanceID == id then
				return (a.applications or 0) >= (minCount or 2) and tostring(a.applications) or ""
			end
		end
		return ""
	end,
}

C_Item = {
	GetItemCount = function(id)
		return S.items[id] or 0
	end,
}

C_AddOns = {
	GetAddOnMetadata = function(_, field)
		if field == "Version" then
			return "0.2.0-test"
		end
	end,
}

C_SpecializationInfo = {
	GetActiveSpecGroup = function()
		return 1
	end,
	GetCombatConfigIDForSpecGroup = function()
		return 42
	end,
}
C_Traits = {
	GetConfigInfo = function()
		return { treeIDs = { 7 } }
	end,
	GetGroupDisplayInfoByTreeID = function()
		local out = {}
		for i, tree in ipairs(S.trees) do
			out[i] = { groupID = 100 + i, displayName = tree[1], icon = 1 }
		end
		return out
	end,
	GetGroupCurrencyInfo = function()
		local out = {}
		for i, tree in ipairs(S.trees) do
			out[i] = { traitNodeGroupID = 100 + i, currencyInfos = { { spent = tree[2] } } }
		end
		return out
	end,
}

Settings = {
	RegisterCanvasLayoutCategory = function(_, name)
		return { ID = 1, name = name, GetID = function()
			return 1
		end }
	end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function() end,
}

SlashCmdList = {}

---------------------------------------------------------------------------
-- Driving the client
---------------------------------------------------------------------------

local function Deliver(f, event, ...)
	local handler = f._scripts.OnEvent
	if handler then
		local ok, err = pcall(handler, f, event, ...)
		if not ok then
			W.errors[#W.errors + 1] = event .. ": " .. tostring(err)
		end
	end
end

function W.Fire(event, ...)
	local unit = ...
	for _, f in ipairs(W.frames) do
		if f._events[event] then
			Deliver(f, event, ...)
		elseif f._unitEvents[event] and f._unitEvents[event][unit] then
			Deliver(f, event, ...)
		end
	end
end

local function RunDue()
	local due, keep = {}, {}
	for _, t in ipairs(W.timers) do
		if t.at <= W.now then
			due[#due + 1] = t
		else
			keep[#keep + 1] = t
		end
	end
	W.timers = keep
	for _, t in ipairs(due) do
		local ok, err = pcall(t.fn)
		if not ok then
			W.errors[#W.errors + 1] = "timer: " .. tostring(err)
		end
	end
	for _, ticker in ipairs(W.tickers) do
		if ticker.nextAt <= W.now then
			ticker.nextAt = W.now + ticker.period
			local ok, err = pcall(ticker.fn)
			if not ok then
				W.errors[#W.errors + 1] = "ticker: " .. tostring(err)
			end
		end
	end
end

function W.Advance(seconds, step)
	step = step or 0.05
	local target = W.now + seconds
	while W.now < target - 1e-9 do
		W.now = math.min(target, W.now + step)
		RunDue()
		for _, f in ipairs(W.frames) do
			local onUpdate = f._scripts.OnUpdate
			if onUpdate and f:IsVisible() then
				local ok, err = pcall(onUpdate, f, step)
				if not ok then
					W.errors[#W.errors + 1] = "OnUpdate: " .. tostring(err)
				end
			end
		end
	end
	RunDue()
end

function W.Slash(text)
	local handler = SlashCmdList.FOREVERDRUID
	local ok, err = pcall(handler, text)
	if not ok then
		W.errors[#W.errors + 1] = "slash " .. text .. ": " .. tostring(err)
	end
end

-- Show the options panel once so every widget's refresher runs.
function W.ShowOptionsPanel()
	for _, f in ipairs(W.frames) do
		if rawget(f, "name") == "ForeverDruid" and f._scripts.OnShow then
			local ok, err = pcall(f._scripts.OnShow, f)
			if not ok then
				W.errors[#W.errors + 1] = "options OnShow: " .. tostring(err)
			end
			return true
		end
	end
	return false
end

function W.LoadAddon(dir, name)
	local ns = {}
	local toc = assert(io.open(dir .. "/" .. name .. ".toc"))
	for line in toc:lines() do
		line = line:gsub("\r", "")
		if line ~= "" and not line:match("^##") then
			local path = dir .. "/" .. line:gsub("\\", "/")
			local chunk = assert(loadfile(path))
			chunk(name, ns)
		end
	end
	toc:close()
	return ns
end

return W
