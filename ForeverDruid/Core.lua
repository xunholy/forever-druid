-- ForeverDruid core: namespace, events, profiles, movable anchors, shared visibility and
-- secret-value helpers.
--
-- WoW Forever runs Midnight's addon rules. The probe (v0.1.0, client 1.60.1.70790) showed the
-- player's mana, rage and energy are secret even out of combat; maximums and combo points are
-- readable; auras turn secret in combat. Addon code may pass secrets straight to widgets
-- (StatusBar:SetValue, FontString:SetFormattedText, Texture:SetTexture,
-- Cooldown:SetCooldownFromExpirationTime) but must not compare them, do arithmetic on them or test
-- them. Every module goes through ns.IsSecret / ns.Readable before using a value with Lua operators.

local ADDON, ns = ...
ForeverDruid = ns -- for /dump and debugging

local L = ns.L

ns.name = ADDON
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
ns.modules = {}
ns.moduleOrder = {}
ns.anchors = {}

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------

local PREFIX = "|cffff7d0aForeverDruid|r:"

function ns.Print(...)
	print(PREFIX, ...)
end

function ns.ReportError(err)
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		handler(err)
	else
		ns.Print("error:", tostring(err))
	end
end

---------------------------------------------------------------------------
-- Secret values
---------------------------------------------------------------------------

local issecretvalue = _G.issecretvalue

-- True when v is a secret value. Safe on any input.
function ns.IsSecret(v)
	if issecretvalue then
		return issecretvalue(v) and true or false
	end
	return false
end

-- Returns v only when Lua may operate on it; nil for secrets.
function ns.Readable(v)
	if ns.IsSecret(v) then
		return nil
	end
	return v
end

-- Calls a C_Secrets predicate if the client has it. Returns true/false, or nil when unknown.
function ns.SecretPredicate(name, ...)
	local api = _G.C_Secrets
	local fn = api and api[name]
	if not fn then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok or ns.IsSecret(result) then
		return nil
	end
	return result and true or false
end

-- Combat state. PLAYER_REGEN_DISABLED fires just before InCombatLockdown() turns true, so anything
-- deciding "are we fighting?" from inside that event must use this instead.
ns.inCombat = false
function ns.InCombat()
	return ns.inCombat or InCombatLockdown()
end

-- Calls fn safely; returns the first result only when the call worked and the result is readable.
function ns.SafeReadable(fn, ...)
	if not fn then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		return nil
	end
	return ns.Readable(result)
end

---------------------------------------------------------------------------
-- Events and internal callbacks
---------------------------------------------------------------------------

local dispatcher = CreateFrame("Frame")
local listeners = {}
local callbacks = {}

local function Dispatch(list, name, ...)
	for i = 1, #list do
		local ok, err = pcall(list[i], name, ...)
		if not ok then
			ns.ReportError(err)
		end
	end
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
	local list = listeners[event]
	if list then
		Dispatch(list, event, ...)
	end
end)

-- Subscribe to a game event. Unknown events (not present on this client) are ignored quietly.
function ns.On(event, fn)
	local list = listeners[event]
	if not list then
		local ok = pcall(dispatcher.RegisterEvent, dispatcher, event)
		if not ok then
			return false
		end
		list = {}
		listeners[event] = list
	end
	list[#list + 1] = fn
	return true
end

-- Subscribe to a unit event for one unit, filtered by the client (no unit-token comparisons in Lua).
local unitFrames = {}
function ns.OnUnit(event, unit, fn)
	local key = event .. "|" .. unit
	local frame = unitFrames[key]
	if not frame then
		frame = CreateFrame("Frame")
		local ok = pcall(frame.RegisterUnitEvent, frame, event, unit)
		if not ok then
			return false
		end
		frame.fdList = {}
		frame:SetScript("OnEvent", function(self, ev, ...)
			Dispatch(self.fdList, ev, ...)
		end)
		unitFrames[key] = frame
	end
	frame.fdList[#frame.fdList + 1] = fn
	return true
end

-- Internal messages between modules (e.g. "FD_ROLE_CHANGED").
function ns.Listen(message, fn)
	local list = callbacks[message]
	if not list then
		list = {}
		callbacks[message] = list
	end
	list[#list + 1] = fn
end

function ns.Fire(message, ...)
	local list = callbacks[message]
	if list then
		Dispatch(list, message, ...)
	end
end

-- Run fn once after `delay` even if requested many times (coalesces bursts of events).
local pending = {}
function ns.Debounce(key, delay, fn)
	if pending[key] then
		return
	end
	pending[key] = true
	C_Timer.After(delay or 0, function()
		pending[key] = nil
		local ok, err = pcall(fn)
		if not ok then
			ns.ReportError(err)
		end
	end)
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------

ns.defaults = {
	unlocked = false,
	positions = {},
	-- The combat HUD stacks itself into one column; `detached` pieces keep their own position.
	layout = { stack = true, gap = 4, detached = {} },
	minimap = { hide = false, angle = 200 }, -- degrees round the ring, 0 = right
	style = { icons = "minimal" },
	preview = true, -- sample icons while unlocked
	macros = { manage = false, enabled = {} }, -- enabled[key] = false to skip one
	ranks = { auto = true, keep = {} },
	role = "auto", -- caster-form role: auto (from talents), healer, balance or feral
	restock = { enabled = false, seeds = 5, thornroot = 10 }, -- buys reagents at vendors when on -- keep[lower-case spell name] = true: leave its rank alone
	grid = false, -- alignment grid while unlocked
	scale = 1.0,
	fadeOutOfCombat = 1.0, -- alpha of the combat HUD when out of combat
	hideWhenMounted = true,
	modules = {
		manabar = {
			enabled = true, scale = 1, width = 160, height = 10,
			alwaysShow = false, text = "value", colorByLevel = true, shiftMarker = true, smooth = true,
		},
		energytick = { enabled = true, scale = 1, width = 160, height = 4 },
		powerbar = { enabled = true, scale = 1, width = 160, height = 12, text = true, smooth = true, tickSpark = true },
		fsr = { enabled = true, scale = 1, width = 160, height = 4, casterOnly = false },
		combopoints = { enabled = true, scale = 1, size = 14, spacing = 3, catOnly = true },
		cooldowns = {
			enabled = true, scale = 1, size = 30, spacing = 4,
			hideOutOfCombat = false, showNumbers = true, tooltips = false, racials = true,
			pulse = true, usableTint = true, rangeTint = true,
			extra = {},
		},
		buffs = { enabled = true, scale = 1, size = 28, spacing = 4 },
		targetauras = { enabled = true, scale = 1, size = 26, spacing = 3, max = 8 },
		reminders = {
			enabled = true, scale = 1, size = 30, clickToCast = true,
			markOfTheWild = true, thorns = false, thornsInBear = true, omenOfClarity = true,
			reagents = true, reagentThreshold = 2, attuned = true, trainer = true, formQuests = true,
		},
	},
	probe = { auto = true },
}

local function CopyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			CopyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
	return target
end

local function DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = DeepCopy(v)
	end
	return out
end

local function CharacterKey()
	local name = UnitName and UnitName("player") or "?"
	local realm = GetRealmName and GetRealmName() or "?"
	return (name or "?") .. " - " .. (realm or "?")
end

function ns.ModuleConfig(key)
	return ns.db.modules[key]
end

function ns.ProfileNames()
	local names = {}
	for name in pairs(ns.global.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- Profile changes take effect after a UI reload (every module re-reads its settings at login).
function ns.UseProfile(name)
	if not ns.global.profiles[name] then
		ns.global.profiles[name] = CopyDefaults({}, ns.defaults)
	end
	ns.global.chars[ns.charKey] = name
end

-- Point ns.db at the stored profile again so edits made before the reload aren't lost.
local function RebindProfile()
	ns.db = CopyDefaults(ns.global.profiles[ns.profileName], ns.defaults)
end

function ns.CopyProfileFrom(name)
	local source = ns.global.profiles[name]
	if not source or name == ns.profileName then
		return false
	end
	ns.global.profiles[ns.profileName] = DeepCopy(source)
	RebindProfile()
	if ns.UpdateRole then
		ns.UpdateRole()
	end
	return true
end

function ns.ResetProfile()
	ns.global.profiles[ns.profileName] = CopyDefaults({}, ns.defaults)
	RebindProfile()
	if ns.UpdateRole then
		ns.UpdateRole()
	end
end

function ns.DeleteProfile(name)
	if name == ns.profileName or not ns.global.profiles[name] then
		return false
	end
	ns.global.profiles[name] = nil
	for char, profile in pairs(ns.global.chars) do
		if profile == name then
			ns.global.chars[char] = "Default"
		end
	end
	return true
end

local function InitDatabase()
	local global = type(ForeverDruidDB) == "table" and ForeverDruidDB or {}
	ForeverDruidDB = global
	global.profiles = global.profiles or {}
	global.chars = global.chars or {}

	ns.charKey = CharacterKey()
	local profileName = global.chars[ns.charKey] or "Default"
	if not global.profiles[profileName] then
		-- v0.1.0 kept settings per character; carry them over into the first profile created.
		local legacy = type(ForeverDruidCharDB) == "table" and next(ForeverDruidCharDB) and ForeverDruidCharDB
		global.profiles[profileName] = legacy and DeepCopy(legacy) or {}
	end
	ForeverDruidCharDB = nil
	global.chars[ns.charKey] = profileName

	ns.global = global
	ns.profileName = profileName
	ns.db = CopyDefaults(global.profiles[profileName], ns.defaults)
end

---------------------------------------------------------------------------
-- Root frame: shared visibility (mounted, dead, vehicles) and out-of-combat fading
---------------------------------------------------------------------------

local root = CreateFrame("Frame", "ForeverDruidRoot", UIParent)
root:SetAllPoints(UIParent)
ns.root = root

local function SafeBool(fn, ...)
	local value = ns.SafeReadable(fn, ...)
	return value and true or false
end

function ns.UpdateVisibility()
	if not ns.db then
		return
	end
	local hidden = false
	if not ns.db.unlocked then
		if ns.db.hideWhenMounted and SafeBool(IsMounted) then
			hidden = true
		elseif SafeBool(UnitIsDeadOrGhost, "player") then
			hidden = true
		elseif SafeBool(UnitInVehicle, "player") or SafeBool(UnitOnTaxi, "player") then
			hidden = true
		end
	end
	root:SetShown(not hidden)
	root:SetScale(ns.db.scale or 1)

	local alpha = (ns.InCombat() or ns.db.unlocked) and 1 or (ns.db.fadeOutOfCombat or 1)
	for _, anchor in pairs(ns.anchors) do
		if anchor.fdFade then
			anchor:SetAlpha(alpha)
		end
	end
end

local function QueueVisibility()
	ns.Debounce("visibility", 0.05, ns.UpdateVisibility)
end
for _, event in ipairs({
	"PLAYER_ENTERING_WORLD", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
	"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
}) do
	ns.On(event, QueueVisibility)
end
-- Registered before any module, so the flag is set before their handlers run.
ns.On("PLAYER_REGEN_DISABLED", function()
	ns.inCombat = true
	-- Last moment keyboard capture may change before lockdown: let every key reach the game.
	for _, anchor in pairs(ns.anchors) do
		anchor:EnableKeyboard(false)
	end
	ns.UpdateVisibility()
end)
ns.On("PLAYER_REGEN_ENABLED", function()
	ns.inCombat = false
	-- Scale changes to secure anchors made during combat were deferred; apply them now.
	ns.ApplyScales()
end)

---------------------------------------------------------------------------
-- Movable anchors
---------------------------------------------------------------------------

local function SavePosition(anchor)
	local point, _, relativePoint, x, y = anchor:GetPoint(1)
	if point then
		ns.db.positions[anchor.fdKey] = { point, relativePoint, x, y }
	end
end

local function RestorePosition(anchor)
	local saved = ns.db.positions[anchor.fdKey]
	local p = saved or anchor.fdDefault
	anchor.fdStackedOn, anchor.fdStackGap = nil, nil -- no longer chained in the stack
	anchor:ClearAllPoints()
	anchor:SetPoint(p[1], anchor.fdSecure and UIParent or root, p[2], p[3], p[4])
end

-- An invisible, draggable container. Modules parent their widgets to it.
-- options.fade: follow the out-of-combat fade setting (combat HUD elements).
-- options.secure: the anchor will hold secure (click-to-cast) buttons. It is parented to UIParent
--   instead of the shared root, because hiding a parent of a secure frame is blocked in combat.
function ns.CreateAnchor(key, width, height, defaultPoint, label, options)
	local parent = (options and options.secure) and UIParent or root
	local anchor = CreateFrame("Frame", "ForeverDruid_" .. key, parent)
	anchor.fdKey = key
	anchor.fdSecure = options and options.secure or false
	anchor.fdDefault = defaultPoint
	anchor.fdFade = options and options.fade or false
	anchor:SetSize(width, height)
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	anchor:RegisterForDrag("LeftButton")
	anchor:SetScript("OnDragStart", function(self)
		if self.fdSecure and InCombatLockdown() then
			return -- moving a frame that holds secure buttons is blocked in combat
		end
		self.fdMoving = ns.BeginDrag(self)
	end)
	anchor:SetScript("OnDragStop", function(self)
		local moving = self.fdMoving or self
		self.fdMoving = nil
		moving:StopMovingOrSizing()
		SavePosition(moving)
	end)
	-- Arrow keys nudge while hovering an unlocked piece; other keys pass through to the game.
	anchor:SetScript("OnEnter", function(self)
		if ns.db.unlocked and not InCombatLockdown() then
			self:EnableKeyboard(true)
			self:SetPropagateKeyboardInput(true)
		end
	end)
	anchor:SetScript("OnLeave", function(self)
		if not InCombatLockdown() then
			self:EnableKeyboard(false)
		end
	end)
	anchor:SetScript("OnKeyDown", function(self, pressed)
		if InCombatLockdown() then
			return
		end
		-- Pass the key on unless it's an arrow we used, even if nudging fails.
		self:SetPropagateKeyboardInput(true)
		local ok, handled = pcall(ns.Nudge, self, pressed, IsShiftKeyDown and IsShiftKeyDown())
		if ok and handled then
			self:SetPropagateKeyboardInput(false)
		end
	end)

	local overlay = anchor:CreateTexture(nil, "OVERLAY")
	overlay:SetAllPoints()
	overlay:SetColorTexture(0.2, 0.8, 0.3, 0.35)
	anchor.fdOverlay = overlay

	local text = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("BOTTOM", anchor, "TOP", 0, 2)
	text:SetText(label or key)
	anchor.fdLabel = text

	ns.anchors[key] = anchor
	ns.ApplyAnchorScale(anchor)
	RestorePosition(anchor)
	ns.ApplyLockState(anchor)
	ns.WatchStackAnchor(anchor)
	return anchor
end

function ns.ApplyLockState(anchor)
	local unlocked = ns.db.unlocked
	if not unlocked and not InCombatLockdown() then
		anchor:EnableKeyboard(false) -- OnLeave may never fire once the mouse is turned off
	end
	anchor:EnableMouse(unlocked)
	anchor.fdOverlay:SetShown(unlocked)
	anchor.fdLabel:SetShown(unlocked)
end

-- Moving or re-enabling mouse on frames that hold secure buttons is blocked in combat.
function ns.SetUnlocked(unlocked)
	if InCombatLockdown() then
		ns.Print(L["can't unlock or lock during combat"])
		return false
	end
	ns.db.unlocked = unlocked and true or false
	for _, anchor in pairs(ns.anchors) do
		ns.ApplyLockState(anchor)
	end
	ns.LayoutStack() -- spacing grows while unlocked so each piece's name fits above it
	ns.UpdateGrid()
	ns.UpdateVisibility()
	ns.Fire("FD_LOCK_CHANGED", ns.db.unlocked)
	return true
end

function ns.ResetPositions()
	if InCombatLockdown() then
		ns.Print(L["can't move frames during combat"])
		return false
	end
	ns.db.positions = {}
	ns.db.layout.detached = {}
	for _, anchor in pairs(ns.anchors) do
		RestorePosition(anchor)
	end
	ns.ApplyLayout()
	return true
end

---------------------------------------------------------------------------
-- Automatic stack
--
-- The combat HUD pieces form one centred column under the character. A piece that is hidden
-- (combo points in Bear Form, the mana bar in caster form, a disabled module) takes no room, so
-- the column closes up instead of leaving a gap, and resizing a piece pushes the ones below it
-- down instead of overlapping them. Dragging any stacked piece moves the whole column;
-- shift-dragging pulls that piece out to a spot of its own.
---------------------------------------------------------------------------

-- Top to bottom. "My effects on target" keeps its row with or without a target, so it goes first
-- and the bars below it don't jump when a DoT lands. Reminders hold secure (click-to-cast)
-- buttons, which may not follow a frame that moves in combat, so they keep their own position.
ns.STACK_ORDER = { "targetauras", "powerbar", "manabar", "fsr", "energytick", "combopoints", "cooldowns", "buffs" }
local STACKABLE = {}
for _, key in ipairs(ns.STACK_ORDER) do
	STACKABLE[key] = true
end
local LABEL_ROOM = 12

-- The column hangs from this invisible point; its position is what gets saved.
local stackHead = CreateFrame("Frame", "ForeverDruid_Stack", root)
stackHead:SetSize(1, 1)
stackHead:SetMovable(true)
stackHead:SetClampedToScreen(true)
stackHead.fdKey = "stack"
stackHead.fdDefault = { "CENTER", "CENTER", 0, -125 }
ns.stackHead = stackHead

function ns.IsStackable(key)
	return STACKABLE[key] or false
end

function ns.IsStacked(anchor)
	if not (ns.db and ns.db.layout.stack and STACKABLE[anchor.fdKey]) then
		return false
	end
	return not ns.db.layout.detached[anchor.fdKey]
end

local laying = false
local function Layout()
	local gap = (ns.db.layout.gap or 4) + (ns.db.unlocked and LABEL_ROOM or 0)
	local previous
	for _, key in ipairs(ns.STACK_ORDER) do
		local anchor = ns.anchors[key]
		if anchor and ns.IsStacked(anchor) and anchor:IsShown() then
			local parent = previous or stackHead
			-- Buffs and target auras refresh several times a second; only re-anchor on a change.
			if anchor.fdStackedOn ~= parent or anchor.fdStackGap ~= gap then
				anchor:ClearAllPoints()
				if previous then
					anchor:SetPoint("TOP", previous, "BOTTOM", 0, -gap)
				else
					anchor:SetPoint("TOP", stackHead, "CENTER", 0, 0)
				end
				anchor.fdStackedOn, anchor.fdStackGap = parent, gap
			end
			previous = anchor
		end
	end
end

-- Re-chains the visible stacked pieces. Cheap, and only touches insecure frames, so it is safe
-- in combat. Sizes need no handling: each piece hangs from the bottom of the one above it.
function ns.LayoutStack()
	if not ns.db or laying then
		return
	end
	laying = true
	local ok, err = pcall(Layout)
	laying = false
	if not ok then
		ns.ReportError(err)
	end
end

-- After the stack setting or a piece's "part of the stack" option changes: pieces that left the
-- stack go back to their own saved (or default) spot, the rest re-chain.
function ns.ApplyLayout()
	if not ns.db then
		return
	end
	RestorePosition(stackHead)
	for key in pairs(STACKABLE) do
		local anchor = ns.anchors[key]
		if anchor and not ns.IsStacked(anchor) then
			RestorePosition(anchor)
		end
	end
	ns.LayoutStack()
end

-- Every show/hide of a stacked piece re-chains the column, wherever it comes from.
function ns.WatchStackAnchor(anchor)
	if not STACKABLE[anchor.fdKey] then
		return
	end
	if not stackHead.fdPlaced then
		stackHead.fdPlaced = true
		RestorePosition(stackHead)
	end
	for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
		hooksecurefunc(anchor, method, ns.LayoutStack)
	end
	ns.LayoutStack()
end

-- Picks what a drag moves: the whole column, or (shift-drag) this piece on its own.
function ns.BeginDrag(anchor)
	if not ns.IsStacked(anchor) then
		anchor:StartMoving()
		return anchor
	end
	if IsShiftKeyDown and IsShiftKeyDown() then
		-- Start moving first so the piece keeps its place on screen as it leaves the column.
		anchor:StartMoving()
		anchor.fdStackedOn, anchor.fdStackGap = nil, nil
		ns.db.layout.detached[anchor.fdKey] = true
		ns.LayoutStack()
		ns.Print(L["moved out of the stack; tick \"Part of the stack\" in /fd config to put it back"])
		return anchor
	end
	stackHead:StartMoving()
	return stackHead
end

-- Stacked pieces are all insecure frames, so these work in combat too.
function ns.SetStackEnabled(enabled)
	ns.db.layout.stack = enabled and true or false
	ns.ApplyLayout()
	return true
end

function ns.SetStacked(key, stacked)
	ns.db.layout.detached[key] = (not stacked) or nil
	ns.ApplyLayout()
	return true
end

local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }

-- Moves what a drag would move (the stack's head for a stacked piece) by 1px, or 10 with Shift.
-- Returns true when the key was an arrow.
function ns.Nudge(anchor, key, big)
	local dir = NUDGE[key]
	if not dir or not ns.db.unlocked then
		return false
	end
	local target = ns.IsStacked(anchor) and ns.stackHead or anchor
	local point, relativeTo, relativePoint, x, y = target:GetPoint(1)
	if not point then
		return true
	end
	local step = big and 10 or 1
	target:ClearAllPoints()
	target:SetPoint(point, relativeTo, relativePoint, (x or 0) + dir[1] * step, (y or 0) + dir[2] * step)
	SavePosition(target)
	return true
end

---------------------------------------------------------------------------
-- Alignment grid while unlocked
---------------------------------------------------------------------------

local grid
local GRID_STEP = 32

local function BuildGrid()
	grid = CreateFrame("Frame", "ForeverDruidGrid", UIParent)
	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	grid.lines = {}
	local function Line(vertical, offset, centre)
		local tex = grid:CreateTexture(nil, "BACKGROUND")
		if centre then
			tex:SetColorTexture(1, 0.3, 0.1, 0.55)
		else
			tex:SetColorTexture(1, 1, 1, 0.12)
		end
		if vertical then
			tex:SetWidth(1)
			tex:SetPoint("TOP", grid, "TOP", offset, 0)
			tex:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
		else
			tex:SetHeight(1)
			tex:SetPoint("LEFT", grid, "LEFT", 0, offset)
			tex:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
		end
		grid.lines[#grid.lines + 1] = tex
	end
	local w = (tonumber(UIParent:GetWidth()) or 1920) / 2
	local h = (tonumber(UIParent:GetHeight()) or 1080) / 2
	for x = 0, w, GRID_STEP do
		Line(true, x, x == 0)
		if x > 0 then
			Line(true, -x)
		end
	end
	for y = 0, h, GRID_STEP do
		Line(false, y, y == 0)
		if y > 0 then
			Line(false, -y)
		end
	end
end

function ns.UpdateGrid()
	local show = ns.db and ns.db.unlocked and ns.db.grid
	if show and not grid then
		BuildGrid()
	end
	if grid then
		grid:SetShown(show and true or false)
	end
end

-- Secure anchors sit outside the root, so they take the global scale themselves.
function ns.ApplyAnchorScale(anchor)
	if anchor.fdSecure and InCombatLockdown() then
		return
	end
	local cfg = ns.db.modules[anchor.fdKey]
	local scale = cfg and cfg.scale or 1
	if anchor.fdSecure then
		scale = scale * (ns.db.scale or 1)
	end
	anchor:SetScale(scale)
end

function ns.ApplyScales()
	for _, anchor in pairs(ns.anchors) do
		ns.ApplyAnchorScale(anchor)
	end
	ns.UpdateVisibility()
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

-- A module is a table with optional :Init() (once), :Enable(), :Disable() and :Refresh().
function ns.RegisterModule(key, module)
	module.key = key
	ns.modules[key] = module
	ns.moduleOrder[#ns.moduleOrder + 1] = key
	return module
end

local function SafeCall(module, method)
	local fn = module[method]
	if fn then
		local ok, err = pcall(fn, module)
		if not ok then
			ns.ReportError(err)
		end
	end
end

function ns.SetModuleEnabled(key, enabled)
	local module = ns.modules[key]
	if not module then
		return false
	end
	ns.db.modules[key].enabled = enabled and true or false
	if not ns.isDruid then
		return true
	end
	if enabled then
		if not module.initialized then
			module.initialized = true
			SafeCall(module, "Init")
		end
		module.enabled = true
		SafeCall(module, "Enable")
		if ns.UpdateVisibility then
			ns.UpdateVisibility() -- apply the out-of-combat fade to the new anchor
		end
	elseif module.enabled then
		module.enabled = false
		SafeCall(module, "Disable")
	end
	return true
end

function ns.RefreshModules()
	for _, key in ipairs(ns.moduleOrder) do
		local module = ns.modules[key]
		if module.enabled then
			SafeCall(module, "Refresh")
		end
	end
end

---------------------------------------------------------------------------
-- Addon compartment (the minimap addon menu)
---------------------------------------------------------------------------

-- Same actions as the minimap button (MinimapButton.lua): quick menu, unlock, full settings.
function ForeverDruid_OnAddonCompartmentClick(_, mouseButton, menuFrame)
	if ns.LauncherClick then
		ns.LauncherClick(menuFrame, mouseButton)
	elseif ns.OpenOptions then
		ns.OpenOptions()
	end
end

function ForeverDruid_OnAddonCompartmentEnter(_, frame)
	if ns.ShowLauncherTooltip then
		ns.ShowLauncherTooltip(frame)
	end
end

function ForeverDruid_OnAddonCompartmentLeave()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

ns.On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then
		return
	end
	InitDatabase()
	ns.Fire("FD_DB_READY")
end)

ns.On("PLAYER_LOGIN", function()
	local _, classFile = UnitClass("player")
	ns.isDruid = classFile == "DRUID"
	ns.Fire("FD_LOGIN")
	if not ns.isDruid then
		-- Keep /fd probe available on other classes; the druid modules stay off.
		return
	end
	for _, key in ipairs(ns.moduleOrder) do
		if ns.db.modules[key] and ns.db.modules[key].enabled then
			ns.SetModuleEnabled(key, true)
		end
	end
	ns.UpdateVisibility()

	if ns.global.lastVersion ~= ns.VERSION then
		if ns.global.lastVersion then
			ns.Print(L["updated to"], ns.VERSION, "-", L["type /fd for commands"])
		else
			ns.Print(L["loaded. Type /fd unlock to place things, /fd for all commands."])
		end
		ns.global.lastVersion = ns.VERSION
	end
end)
