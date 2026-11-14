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
	return W.locale or "enUS"
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
-- Unknown API methods (PascalCase, like the client's) become no-ops; anything else, such as a
-- field the addon attaches itself, reads as nil exactly as on a real frame.
Frame.__index = function(self, key)
	local method = Frame[key]
	if method ~= nil then
		return method
	end
	if type(key) == "string" and key:match("^%u") then
		return function()
			return nil
		end
	end
	return nil
end

local function NewObject(kind, parent, template)
	local o = setmetatable({ _kind = kind, _parent = parent, _template = template, _shown = true, _scripts = {},
		_events = {}, _unitEvents = {}, _attributes = {}, _w = 0, _h = 0, _alpha = 1, _scale = 1,
		_points = {}, _values = {} }, Frame)
	W.frames[#W.frames + 1] = o
	return o
end

local SECURE_TEMPLATES = { SecureActionButtonTemplate = true, SecureUnitButtonTemplate = true,
	SecureGroupHeaderTemplate = true }
local function IsProtected(frame)
	if SECURE_TEMPLATES[rawget(frame, "_template") or ""] then
		return true
	end
	for _, f in ipairs(W.frames) do
		if SECURE_TEMPLATES[rawget(f, "_template") or ""] then
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
function Frame:CreateMaskTexture()
	return NewObject("MaskTexture", self)
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
function Frame:RegisterForClicks(...)
	GuardProtected(self, "RegisterForClicks")
	self._clicks = { ... }
end
function Frame:EnableKeyboard(v)
	self._keyboard = v and true or false
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
function Frame:SetValue(v, interpolation)
	self._values.value = v
	self._interpolation = interpolation
end
-- Accepts secret booleans like the client: records them without testing them.
function Frame:SetVertexColorFromBoolean(value, ifTrue, ifFalse)
	self._colorBool = value
	self._colorIfTrue, self._colorIfFalse = ifTrue, ifFalse
end
function Frame:SetVertexColor(r, g, b, a)
	self._vertex = { r, g, b, a }
	self._colorBool = nil
end
function Frame:SetTexCoord(...)
	self._texcoord = { ... }
end
function Frame:CreateAnimationGroup()
	local group = { _plays = 0 }
	function group:CreateAnimation()
		return setmetatable({}, { __index = function()
			return function() end
		end })
	end
	function group:Play()
		self._plays = self._plays + 1
	end
	function group:Stop() end
	function group:SetLooping(mode)
		self._looping = mode
	end
	return group
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
ItemRefTooltip = NewObject("GameTooltip")
ShoppingTooltip1 = NewObject("GameTooltip")

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
	if W.state and W.state.inCombat and SECURE_TEMPLATES[template or ""] then
		W.blocked[#W.blocked + 1] = "CreateFrame secure"
		error("ADDON_ACTION_BLOCKED: creating a secure frame in combat")
	end
	local f = NewObject(kind, parent, template)
	if name then
		_G[name] = f
	end
	if template == "SecureGroupHeaderTemplate" then
		-- Like Blizzard's header: on Show and roster changes it makes one secure unit button per
		-- member (player first), copying _initialAttribute-* onto new buttons.
		W.headers = W.headers or {}
		W.headers[#W.headers + 1] = f
		local show = f.Show
		rawset(f, "Show", function(self)
			show(self)
			W.UpdateHeaders()
		end)
	end
	if template == "InputScrollFrameTemplate" then
		f.EditBox = NewObject("EditBox", f)
	end
	return f
end

-- Macros like the client: account slots 1-120, character slots 121-150, each list sorted by name,
-- 16-character names, 255-character bodies, and no changes during combat lockdown.
W.macros = { account = {}, character = {} }
local function MacroLookup(index)
	if index > 120 then
		return W.macros.character[index - 120], W.macros.character, index - 120
	end
	return W.macros.account[index], W.macros.account, index
end
local function SortMacros()
	for _, list in pairs(W.macros) do
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
	end
end
local function GuardMacro(what)
	if W.state.inCombat then
		W.blocked[#W.blocked + 1] = what
		error("ADDON_ACTION_BLOCKED: " .. what .. " in combat")
	end
end
function GetNumMacros()
	return #W.macros.account, #W.macros.character
end
function GetMacroIndexByName(name)
	for i, m in ipairs(W.macros.account) do
		if m.name == name then
			return i
		end
	end
	for i, m in ipairs(W.macros.character) do
		if m.name == name then
			return 120 + i
		end
	end
	return 0
end
-- Like the client, macro text comes back with a trailing line break.
function GetMacroInfo(index)
	local m = MacroLookup(index)
	if m then
		local body = m.body or ""
		if body:sub(-1) ~= "\n" then
			body = body .. "\n"
		end
		return m.name, m.icon, body
	end
end
function CreateMacro(name, icon, body, perCharacter)
	GuardMacro("CreateMacro")
	assert(#name <= 16, "macro name too long: " .. name)
	assert(not body or #body <= 255, "macro body too long")
	local list = perCharacter and W.macros.character or W.macros.account
	assert(#list < (perCharacter and 30 or 120), "no free macro slots")
	list[#list + 1] = { name = name, icon = icon, body = body or "" }
	SortMacros()
	return GetMacroIndexByName(name)
end
function EditMacro(index, name, icon, body)
	GuardMacro("EditMacro")
	local m = assert(MacroLookup(index), "no macro at " .. tostring(index))
	m.name, m.icon = name or m.name, icon or m.icon
	if body then
		assert(#body <= 255, "macro body too long")
		m.body = body
	end
	SortMacros()
	return GetMacroIndexByName(m.name)
end
function DeleteMacro(index)
	GuardMacro("DeleteMacro")
	local m, list, i = MacroLookup(index)
	if m then
		table.remove(list, i)
	end
end
function PickupMacro(index)
	local m = MacroLookup(index)
	W.pickedMacro = m and m.name
end
function W.CharacterMacro(name)
	for _, m in ipairs(W.macros.character) do
		if m.name == name then
			return m
		end
	end
end

-- Secure state drivers: "[form:N] name; ...; default" evaluated against the current form, running
-- the frame's _onstate-<state> snippet (as the secure environment would) whenever it changes.
W.stateDrivers = {}
function RegisterStateDriver(frame, state, values)
	W.stateDrivers[#W.stateDrivers + 1] = { frame = frame, state = state, values = values }
	W.UpdateStateDrivers()
end
local function EvaluateConditions(values)
	for raw in (values .. ";"):gmatch("([^;]*);") do
		local clause = raw:match("^%s*(.-)%s*$")
		local cond, result = clause:match("^%[(.-)%]%s*(.*)$")
		if not cond then
			return clause
		end
		local formNumbers = cond:match("^form:([%d/]+)$")
		if formNumbers then
			for n in formNumbers:gmatch("%d+") do
				if tonumber(n) == W.state.form then
					return result
				end
			end
		end
	end
end
function W.UpdateStateDrivers()
	for _, d in ipairs(W.stateDrivers) do
		local new = EvaluateConditions(d.values)
		if new ~= d.current then
			d.current = new
			local snippet = d.frame:GetAttribute("_onstate-" .. d.state)
			if snippet then
				local chunk = assert(load(snippet, "snippet", "t", setmetatable({ self = d.frame, newstate = new }, { __index = _G })))
				chunk()
			end
		end
	end
end

-- Blizzard's rotation helper: W.state.assisted = { available=, reason=, next= }.
C_AssistedCombat = {
	IsAvailable = function()
		local a = W.state.assisted
		return a and a.available or false, a and a.reason or "not available"
	end,
	GetNextCastSpell = function()
		local a = W.state.assisted
		return a and a.next
	end,
	GetRotationSpells = function()
		return { 1082, 1822, 1079 }
	end,
}
-- A main action bar: ActionButton1..12 showing slots 1..12.
ActionButtonUtil = { ActionBarButtonNames = { "ActionButton" } }
for i = 1, 12 do
	local button = NewObject("CheckButton", UIParent, "ActionBarButtonTemplate")
	button.action = i
	_G["ActionButton" .. i] = button
end

function W.UpdateHeaders()
	for _, header in ipairs(W.headers or {}) do
		if header:IsShown() then
			local units = { "player" }
			for i = 1, 4 do
				if W.state.party and W.state.party["party" .. i] then
					units[#units + 1] = "party" .. i
				end
			end
			-- A negative startingIndex makes the header create extra (empty) buttons up front.
			local start = tonumber(header:GetAttribute("startingIndex")) or 1
			local make = math.max(#units, start < 1 and (#units - start + 1) or 0)
			for i = #units + 1, math.min(make, 5) do
				if not rawget(header, i) then
					local button = NewObject("Button", header, "SecureUnitButtonTemplate")
					rawset(header, i, button)
					button._shown = false
				end
			end
			for i, unit in ipairs(units) do
				local button = rawget(header, i)
				if not button then
					-- Created by the secure code, so allowed even in combat.
					button = NewObject("Button", header, "SecureUnitButtonTemplate")
					rawset(header, i, button)
					local names = header:GetAttribute("_initialAttributeNames")
					for name in tostring(names or ""):gmatch("[^,]+") do
						button._attributes[name] = header:GetAttribute("_initialAttribute-" .. name)
					end
				end
				button._attributes.unit = unit
				button._shown = true
			end
			for i = #units + 1, 5 do
				local button = rawget(header, i)
				if button then
					button._attributes.unit = nil
					button._shown = false
				end
			end
		end
	end
end
function UnitInRange()
	return W.Secret()
end

-- Tooltips: hooks registered through TooltipDataProcessor; W.ShowItemTooltip(link) runs them.
W.tooltipHooks = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		W.tooltipHooks[#W.tooltipHooks + 1] = { kind = kind, fn = fn }
	end,
}
-- Shows an item on GameTooltip (or `tooltip`) and returns the lines hooks added.
function W.ShowItemTooltip(link, tooltip)
	local tip = tooltip or GameTooltip
	local lines = {}
	rawset(tip, "GetItem", function()
		return "Item", link
	end)
	rawset(tip, "AddLine", function(_, text, r, g, b)
		lines[#lines + 1] = { text = text, r = r, g = g, b = b }
	end)
	for _, hook in ipairs(W.tooltipHooks) do
		if hook.kind == Enum.TooltipDataType.Item then
			hook.fn(tip)
		end
	end
	return lines
end
W.itemStats, W.itemSlots, W.equipped = {}, {}, {}
function GetInventoryItemLink(_, slot)
	return W.equipped[slot]
end

-- Popups: recorded, and accepted or declined by the test.
StaticPopupDialogs = {}
UISpecialFrames = {}
W.popups = {}
function StaticPopup_Show(which, text, _, data)
	W.popups[#W.popups + 1] = { which = which, text = text, data = data }
end
function W.AcceptPopup()
	local popup = table.remove(W.popups)
	if popup then
		StaticPopupDialogs[popup.which].OnAccept(nil, popup.data)
		return true
	end
	return false
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
	function ticker:Cancel()
		self.cancelled = true
	end
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
	spellUsable = true, spellNoPower = false, spellInRange = nil,
	manaCost = { [774] = 25, [1058] = 40, [1430] = 60, [5185] = 55 }, energyCost = { [1082] = 45 },
	ranks = { [774] = { "Rejuvenation", 1 }, [1058] = { "Rejuvenation", 2 }, [1430] = { "Rejuvenation", 3 } },
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
	extraNames = { [16870] = "Clearcasting", [1259691] = "Attuned", [1126] = "Mark of the Wild", [467] = "Thorns",
		[774] = "Rejuvenation", [1058] = "Rejuvenation", [1430] = "Rejuvenation", [1082] = "Claw" },
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
	TooltipDataType = { Item = 0, Spell = 1, Unit = 2 },
	PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4 },
	SpellBookSpellBank = { Player = 0, Pet = 1 },
	SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
	AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
	LuaCurveType = { Linear = 0, Step = 1 },
}

-- Party members: W.state.party = { party1 = { name=, class=, role=, dead=, hots={...} }, ... }
local function Member(unit)
	return S.party and S.party[unit]
end

-- Nameplate units: W.state.plates = { nameplate1 = { level=, canAttack=, reaction=, combat=, dead=,
-- isPlayer=, npcID=, name=, guid=, range = { min, max }, targetsPlayer=, auras = { [spellID] = true } } }.
-- Any field may be W.Secret(). "nameplate1target" resolves through targetsPlayer.
local function Plate(unit)
	local base = type(unit) == "string" and unit:match("^(nameplate%d+)")
	return base and S.plates and S.plates[base], base
end
W.Plate = Plate
function UnitClass(unit)
	local m = Member(unit)
	if m then
		return m.class, m.class
	end
	return "Druid", S.class
end
function UnitGroupRolesAssigned(unit)
	local m = Member(unit)
	return m and m.role or "NONE"
end
function IsInGroup()
	return S.party ~= nil and next(S.party) ~= nil
end
W.sounds = {}
function PlaySound(kit)
	W.sounds[#W.sounds + 1] = kit
end
function UnitRace()
	return "Skyborne", S.race
end
function UnitName(unit)
	local p = Plate(unit)
	if p then
		return p.name
	end
	local m = Member(unit)
	if m then
		return S.secretNames and W.Secret() or m.name
	end
	return "Testdruid"
end
function GetRealmName()
	return "Testrealm"
end
function UnitLevel(unit)
	local p = Plate(unit)
	if p then
		return p.level
	end
	return W.state.level or 40
end
-- W.state.threat: a number (0-3) to make threat readable; otherwise secret in combat.
function UnitThreatSituation()
	if W.state.threat ~= nil then
		return W.state.threat
	end
	return W.state.inCombat and W.Secret() or nil
end
function UnitAttackSpeed()
	return 2.5
end

-- Merchant: W.merchant = { { item=, name=, price=, stackCount=, numAvailable= }, ... }
W.merchant = {}
W.bought = {}
W.money = 100000
function GetMoney()
	return W.money
end
function GetMerchantNumItems()
	return #W.merchant
end
function GetMerchantItemMaxStack(i)
	return W.merchant[i] and W.merchant[i].maxStack or 20
end
function IsTradeskillTrainer()
	return W.tradeskillTrainer or false
end
function GetMerchantItemID(i)
	return W.merchant[i] and W.merchant[i].item
end
C_MerchantFrame = {
	GetItemInfo = function(i)
		local m = W.merchant[i]
		return m and { name = m.name, price = m.price, stackCount = m.stackCount or 1, numAvailable = m.numAvailable or -1,
			isPurchasable = true, hasExtendedCost = false }
	end,
}
function BuyMerchantItem(i, count)
	local m = W.merchant[i]
	W.bought[#W.bought + 1] = { item = m.item, count = count }
	W.money = W.money - m.price * count
	W.state.items[m.item] = (W.state.items[m.item] or 0) + count
end
function InCombatLockdown()
	return S.inCombat
end
function UnitIsDeadOrGhost(unit)
	local m = Member(unit)
	return m and m.dead or false
end
function UnitIsDead(unit)
	local p = Plate(unit)
	if p then
		return p.dead or false
	end
	local m = Member(unit)
	return m and m.dead or false
end
function UnitIsPlayer(unit)
	local p = Plate(unit)
	if p then
		return p.isPlayer or false
	end
	return unit == "player" or Member(unit) ~= nil
end
function UnitReaction(unit)
	local p = Plate(unit)
	if p then
		return p.reaction
	end
	return S.targetHostile and 2 or 5
end
function UnitAffectingCombat(unit)
	local p = Plate(unit)
	if p then
		return p.combat or false
	end
	return unit == "player" and S.inCombat or false
end
function UnitGUID(unit)
	local p = Plate(unit)
	if p then
		if p.guid ~= nil then
			return p.guid
		end
		return p.npcID and ("Creature-0-1-0-1-%d-0000000001"):format(p.npcID) or nil
	end
	return unit == "player" and "Player-1-00000001" or nil
end
function UnitIsUnit(a, b)
	local p, base = Plate(a)
	if p and a == base .. "target" and b == "player" then
		return p.targetsPlayer or false
	end
	return a == b
end
function UnitClassification(unit)
	local p = Plate(unit)
	return p and (p.classification or "normal") or "normal"
end
function IsStealthed()
	return S.stealthed or false
end
function GetRealZoneText()
	return "Teldrassil"
end
C_NamePlate = {
	GetNamePlateForUnit = function(unit)
		return W.plateFrames and W.plateFrames[unit]
	end,
}
-- Adds a nameplate unit and fires NAME_PLATE_UNIT_ADDED, like a mob coming into view.
function W.AddPlate(token, unit)
	S.plates = S.plates or {}
	W.plateFrames = W.plateFrames or {}
	S.plates[token] = unit
	W.plateFrames[token] = W.plateFrames[token] or CreateFrame("Frame", nil, UIParent)
	W.Fire("NAME_PLATE_UNIT_ADDED", token)
end
function W.RemovePlate(token)
	W.Fire("NAME_PLATE_UNIT_REMOVED", token)
	S.plates[token] = nil
	W.plateFrames[token] = nil
end
-- The aggro marker on a unit's plate: the frame the addon parented to that plate.
function W.MarkerOn(token)
	local plate = W.plateFrames and W.plateFrames[token]
	for _, f in ipairs(W.frames) do
		if plate and rawget(f, "_parent") == plate and rawget(f, "_kind") == "Frame" then
			return f
		end
	end
end
-- LibRangeCheck-3.0 stand-in (Libs\ aren't loaded here): GetRange returns the plate's bracket.
local rangeCheck = {}
function rangeCheck:GetRange(unit)
	local p = Plate(unit)
	if not (p and p.range) then
		return nil
	end
	return p.range[1], p.range[2]
end
LibStub = setmetatable({
	GetLibrary = function(_, major)
		if major == "LibRangeCheck-3.0" then
			return rangeCheck, 39
		end
	end,
}, {
	__call = function(_, major)
		if major == "LibRangeCheck-3.0" then
			return rangeCheck
		end
	end,
})
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
function UnitExists(unit)
	if unit == "player" then
		return true
	elseif unit and unit:find("^nameplate") then
		return Plate(unit) ~= nil
	elseif unit and unit:find("^party") then
		return Member(unit) ~= nil
	end
	return S.targetExists
end
function UnitCanAttack(_, unit)
	local p = Plate(unit)
	if p then
		return p.canAttack or false
	end
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
-- Target health is secret to addons; with a curve the client evaluates it and returns a secret.
function UnitHealthPercent(unit, _, curve)
	W.healthQueries = (W.healthQueries or 0) + 1
	if curve then
		return W.Secret()
	end
	return W.Secret()
end
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

Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
Enum.AddOnProfilerMetric = { SessionAverageTime = 0, RecentAverageTime = 1, EncounterAverageTime = 2, LastTime = 3,
	PeakTime = 4, CountTimeOver1Ms = 5, CountTimeOver5Ms = 6 }
-- Profiler numbers in ms; the test sets W.state.cpu.
C_AddOnProfiler = {
	IsEnabled = function()
		return S.cpu ~= nil
	end,
	GetAddOnMetric = function(_, metric)
		return S.cpu and S.cpu[metric]
	end,
	GetOverallMetric = function(metric)
		return S.cpu and S.cpu.overall and S.cpu.overall[metric]
	end,
}

C_Spell = {
	IsSpellUsable = function()
		return S.spellUsable, S.spellNoPower
	end,
	IsSpellInRange = function()
		return S.spellInRange
	end,
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
		local cost = S.formCost[id] or S.manaCost[id]
		if S.energyCost[id] then
			return { { type = 3, cost = S.energyCost[id] } }
		end
		return cost and { { type = 0, cost = cost } } or {}
	end,
	PickupSpell = function(id)
		if W.pickupFails then
			return -- the client quietly refusing
		end
		W.cursorItem = { kind = "spell", id = id }
	end,
	GetSpellSubtext = function(id)
		local rank = S.ranks[id]
		return rank and ("Rank " .. rank[2]) or ""
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
	-- Entries marked low = true are lower ranks shown with "Show all spell ranks".
	IsSpellBookItemLowRank = function(slot)
		local entry = S.spellbook[slot]
		return entry and entry.low or false
	end,
}

-- Spell ranks: W.state.ranks[id] = { name, rankNumber }. The highest known rank is the spellbook
-- entry (not marked low) with that name.
local function HighestKnown(name)
	for _, entry in ipairs(S.spellbook) do
		if entry[2] == name and not entry.low then
			return entry[1]
		end
	end
end
C_ActionBar = {
	IsHighestSpellRank = function(id)
		local rank = S.ranks[id]
		if not rank then
			return true
		end
		return HighestKnown(rank[1]) == id
	end,
}

-- Action bars and the cursor, like the client: PlaceAction swaps the cursor into the slot and the
-- slot's old action onto the cursor; refused in combat.
W.actions = {}
W.cursorItem = nil
function GetActionInfo(slot)
	local a = W.actions[slot]
	if a then
		return a.kind, a.id
	end
end
function GetCursorInfo()
	return W.cursorItem and W.cursorItem.kind or nil
end
function ClearCursor()
	W.cursorItem = nil
end
function PlaceAction(slot)
	if W.state.inCombat then
		W.blocked[#W.blocked + 1] = "PlaceAction"
		error("ADDON_ACTION_BLOCKED: PlaceAction in combat")
	end
	local old = W.actions[slot]
	W.actions[slot] = W.cursorItem
	W.cursorItem = old
end

local function AuraFor(name)
	local a = S.auras[name]
	if not a then
		return nil
	end
	return { name = name, spellId = a.spellId or 1, icon = 1000 + (a.spellId or 1), duration = a.duration or 0,
		expirationTime = a.expirationTime or 0, applications = a.applications or 0, auraInstanceID = a.auraInstanceID or 1 }
end

C_UnitAuras = {
	-- Nameplate units only (the aggro radius reads Soothe debuffs on mobs); W.Secret() marks a secret aura.
	GetUnitAuraBySpellID = function(unit, spellID)
		local p = Plate(unit)
		local a = p and p.auras and p.auras[spellID]
		if a == true then
			return { spellId = spellID }
		end
		return a
	end,
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
		local m = Member(unit)
		if m or (unit == "player" and filter:find("HELPFUL", 1, true) and filter:find("PLAYER", 1, true)) then
			local out = {}
			for _, a in ipairs((m and m.hots) or S.selfHots or {}) do
				if S.secretAuras then
					out[#out + 1] = { icon = W.Secret(), expirationTime = W.Secret(), duration = W.Secret(), name = W.Secret() }
				else
					out[#out + 1] = { icon = a.icon, expirationTime = a.expirationTime, duration = a.duration, name = a.name }
				end
			end
			return out
		end
		if unit ~= "target" or not S.targetExists then
			return {}
		end
		-- "HARMFUL" without PLAYER: every debuff, including other players' (missing-debuff check).
		if filter == "HARMFUL" then
			local out = {}
			for _, a in ipairs(S.targetAuras) do
				out[#out + 1] = { name = S.secretAuras and W.Secret() or a.name }
			end
			for _, name in ipairs(S.targetOtherDebuffs or {}) do
				out[#out + 1] = { name = S.secretAuras and W.Secret() or name }
			end
			return out
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
					applications = W.Secret(), auraInstanceID = W.Secret(), name = W.Secret() }
			else
				out[i] = { icon = a.icon, expirationTime = a.expirationTime, duration = a.duration,
					applications = a.applications, auraInstanceID = a.auraInstanceID, name = a.name }
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
	GetItemStats = function(link)
		return W.itemStats[link]
	end,
	GetItemInfoInstant = function(link)
		return W.itemIDs[link] or 1, "Armor", "Leather", W.itemSlots[link]
	end,
	-- Items in your bags you can't use (too high a level): W.unusable[itemID] = true.
	IsUsableItem = function(id)
		return not W.unusable[id], false
	end,
}
W.itemIDs, W.unusable = {}, {}

-- Bags: W.bags[bag][slot] = item link (bags 0-4).
W.bags = {}
C_Container = {
	GetContainerNumSlots = function(bag)
		return W.bags[bag] and 16 or 0
	end,
	GetContainerItemLink = function(bag, slot)
		return W.bags[bag] and W.bags[bag][slot]
	end,
}

-- Character-sheet stat conversions, with simple stand-in rates: 20 Agility per 1% crit, 60 Intellect
-- per 1% spell crit, 10 health per Stamina, 14 crit rating per 1%, 10 of other ratings per 1% (1 per
-- point of defense). W.state.statsSecret = true hides them, as Forever does when unit stats are
-- restricted. GetCritChanceFromStat and friends return fractions, as the client's do.
local function StatSecret(v)
	return S.statsSecret and W.Secret() or v
end
function GetCritChanceFromStat(stat, value)
	return StatSecret(stat == 2 and value / 20 / 100 or 0)
end
function GetSpellCritChanceFromStat(stat, value)
	return StatSecret(stat == 4 and value / 60 / 100 or 0)
end
function GetCombatRatingBonusForCombatRatingValue(rating, value)
	local per = ({ [9] = 14, [11] = 14, [2] = 1 })[rating] or 10
	return StatSecret(value / per)
end
function UnitHPPerStamina()
	return 10
end
function GetDodgeChanceFromAttribute()
	return StatSecret(0.05) -- 5% from 100 Agility
end
function UnitStat(_, index)
	return StatSecret(100), StatSecret(index == 2 and 100 or 50)
end
MANA_PER_INTELLECT = 15

C_AddOns = {
	-- Reads the real TOC, like the client.
	GetAddOnMetadata = function(_, field)
		local toc = io.open("ForeverDruid/ForeverDruid.toc")
		if not toc then
			return nil
		end
		for line in toc:lines() do
			local key, value = line:match("^## ([%w%-]+):%s*(.-)%s*$")
			if key == field then
				toc:close()
				return value
			end
		end
		toc:close()
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
	GetTreeCurrencyInfo = function()
		return { { quantity = S.unspentTalents or 0, spent = 0 } }
	end,
}

W.settingsPages = {}
local function Category(frame, name)
	local id = #W.settingsPages + 1
	W.settingsPages[id] = { frame = frame, name = name }
	return { ID = id, name = name, GetID = function()
		return id
	end }
end
Settings = {
	RegisterCanvasLayoutCategory = function(frame, name)
		return Category(frame, name)
	end,
	RegisterCanvasLayoutSubcategory = function(_, frame, name)
		return Category(frame, name)
	end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function(id)
		W.openedCategory = id
	end,
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
		if not ticker.cancelled and ticker.nextAt <= W.now then
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
-- Shows every registered settings page (main and sub-pages); true if at least one exists.
function W.ShowOptionsPanel()
	local shown = 0
	for _, page in ipairs(W.settingsPages) do
		local onShow = page.frame._scripts.OnShow
		if onShow then
			local ok, err = pcall(onShow, page.frame)
			if not ok then
				W.errors[#W.errors + 1] = "options OnShow (" .. tostring(page.name) .. "): " .. tostring(err)
			end
			shown = shown + 1
		end
	end
	return shown > 0, shown
end

function W.LoadAddon(dir, name)
	local ns = {}
	local toc = assert(io.open(dir .. "/" .. name .. ".toc"))
	for raw in toc:lines() do
		local line = raw:gsub("\r", "")
		if line ~= "" and not line:match("^##") and not line:match("^Libs\\") then
			local path = dir .. "/" .. line:gsub("\\", "/")
			local chunk = assert(loadfile(path))
			chunk(name, ns)
		end
	end
	toc:close()
	return ns
end

return W
