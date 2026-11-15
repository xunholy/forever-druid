-- Creates the druid macros in MacroList.lua and keeps them up to date.
--
-- Only macros named "FD ..." are ever touched, and only ones ForeverDruid wrote itself: the body
-- it last wrote is remembered, and a macro whose text no longer matches (you edited it) is left
-- alone. Each macro goes where you choose: the account's 120 general slots (every character on
-- the account sees those) or this character's own 30. Changing the choice moves the macro and puts
-- it back on the action buttons it was on.
--
-- Nothing is deleted because a spell seems unknown (the spellbook can be empty for a moment at
-- login); a macro is only removed when you untick it or turn macro management off.

local _, ns = ...
local L = ns.L
local M = ns.macros
local BY_KEY, FormIndex, S = M.BY_KEY, M.FormIndex, M.SpellName
local ICON, MAX_CHARACTER_MACROS, MAX_ACCOUNT_MACROS = M.ICON, M.MAX_CHARACTER_MACROS, M.MAX_ACCOUNT_MACROS
local MAX_ACTION_SLOTS = 180

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function Config()
	return ns.db.macros
end

-- Bodies ForeverDruid last wrote. Character macros: global.macroBodies[charKey][key] = body.
-- Account macros are shared, so their record is too: global.macroBodiesAccount[key] = body. Any
-- druid on the account then keeps them up to date for itself when it logs in.
local function CharacterRecords()
	ns.global.macroBodies = ns.global.macroBodies or {}
	local mine = ns.global.macroBodies[ns.charKey]
	if not mine then
		mine = {}
		ns.global.macroBodies[ns.charKey] = mine
	end
	return mine
end

local function AccountRecords()
	ns.global.macroBodiesAccount = ns.global.macroBodiesAccount or {}
	return ns.global.macroBodiesAccount
end

local function Recorded(key)
	return AccountRecords()[key] or CharacterRecords()[key]
end

-- body = nil forgets it.
local function Record(key, body, place)
	AccountRecords()[key], CharacterRecords()[key] = nil, nil
	if body then
		(place == "account" and AccountRecords() or CharacterRecords())[key] = body
	end
end

-- Where you want a macro: your choice for it, otherwise the default for all of them.
function M.Place(key)
	local cfg = Config()
	local own = cfg.places and cfg.places[key]
	if own == "account" or own == "character" then
		return own
	end
	return cfg.place == "character" and "character" or "account"
end

-- Where a macro is: account macros are numbered 1-120, character macros after that.
local function PlaceOf(index)
	return index <= MAX_ACCOUNT_MACROS and "account" or "character"
end
M.PlaceOf = PlaceOf

local function SlotsFree(place)
	local account, character = GetNumMacros()
	if place == "account" then
		return MAX_ACCOUNT_MACROS - (tonumber(account) or 0)
	end
	return MAX_CHARACTER_MACROS - (tonumber(character) or 0)
end

-- Ticked in the settings: your choice if you made one, otherwise the macro's default.
function M.IsTicked(key)
	local choice = Config().enabled[key]
	if choice ~= nil then
		return choice and true or false
	end
	local def = BY_KEY[key]
	return not (def and def.default == false)
end

function M.IsWanted(key)
	return Config().manage and M.IsTicked(key)
end

-- Each need is a spell key, or a list of keys where any one will do (Dire Bear Form replaces
-- Bear Form at 40).
function M.HasSpells(def)
	for _, need in ipairs(def.needs) do
		local options = type(need) == "table" and need or { need }
		local any = false
		for _, spell in ipairs(options) do
			any = any or ns.IsCastable(spell)
		end
		if not any then
			return false, options[#options]
		end
	end
	return true
end

-- A body is only ever built once every spell name is known (never "nil" in a macro).
local function Body(def)
	if not M.HasSpells(def) or (def.ready and not def.ready()) then
		return nil
	end
	local ok, body = pcall(def.body)
	if ok and type(body) == "string" and #body <= 255 then
		return body
	end
	return nil
end
M.Body = Body

-- The game stores macro text with its own line endings and a trailing line break, so compare
-- text with those ignored. A strict == made every FD macro look "edited by you" once it had been
-- saved, and ForeverDruid then never updated it.
local function Norm(text)
	if type(text) ~= "string" then
		return text
	end
	return (text:gsub("\r\n", "\n"):gsub("%s+$", ""))
end
local function Same(a, b)
	return Norm(a) == Norm(b)
end
M.SameText = Same

-- The macro for a definition: by its name, or by a name it had before (renamed macros keep their
-- slot, so they stay on your action bars). An old name only counts if ForeverDruid wrote a macro
-- for this definition, so a macro of yours that happens to have an old FD name is never adopted.
-- Returns index, body, and the old name if found by one.
local function Existing(def)
	if not GetMacroIndexByName then
		return nil
	end
	local index = GetMacroIndexByName(def.name)
	if index and index > 0 then
		local _, _, body = GetMacroInfo(index)
		return index, body
	end
	if not Recorded(def.key) then
		return nil
	end
	for _, name in ipairs(def.renamedFrom or {}) do
		index = GetMacroIndexByName(name)
		if index and index > 0 then
			local _, _, body = GetMacroInfo(index)
			return index, body, name
		end
	end
	return nil
end

-- "ready", "edited" (you changed it: left alone), "missing" (not created yet),
-- "needs" (a spell isn't learned yet), "off".
function M.Status(key)
	local def = BY_KEY[key]
	local index, body = Existing(def)
	local written = Recorded(key)
	if index and written and not Same(body, written) then
		return "edited"
	end
	if not M.IsWanted(key) then
		return "off"
	end
	if index then
		return "ready"
	end
	if M.HasSpells(def) and (not def.ready or def.ready()) and GetNumMacros and SlotsFree(M.Place(key)) <= 0 then
		return "full"
	end
	local has, missing = M.HasSpells(def)
	if not has then
		return "needs", missing
	end
	if def.ready then
		local ok, what = def.ready()
		if not ok then
			return "needs", L[what]
		end
	end
	return "missing"
end

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------

M.lastSync = { created = 0, updated = 0, removed = 0, skipped = 0, full = false }
local pending = false

-- Macro slots, for each place: { max, used, free, ours (FD macros there), waiting (ticked and
-- ready, but that place is full) }.
function M.Slots()
	local out = {}
	for _, place in ipairs({ "account", "character" }) do
		local max = place == "account" and MAX_ACCOUNT_MACROS or MAX_CHARACTER_MACROS
		local free = GetNumMacros and SlotsFree(place) or max
		out[place] = { max = max, used = max - free, free = free, ours = 0, waiting = 0 }
	end
	for _, def in ipairs(M.LIST) do
		local index = Existing(def)
		if index then
			local at = out[PlaceOf(index)]
			at.ours = at.ours + 1
		else
			local want = out[M.Place(def.key)]
			if want.free <= 0 and M.IsWanted(def.key) and M.HasSpells(def) and (not def.ready or def.ready()) then
				want.waiting = want.waiting + 1
			end
		end
	end
	return out
end

-- Action bar slots holding a macro by this name.
local function ButtonsWith(name)
	local slots = {}
	local textOf = (C_ActionBar and C_ActionBar.GetActionText) or GetActionText
	if not (GetActionInfo and textOf) then
		return slots
	end
	for slot = 1, MAX_ACTION_SLOTS do
		local kind = ns.SafeReadable(GetActionInfo, slot)
		if kind == "macro" and ns.SafeReadable(textOf, slot) == name then
			slots[#slots + 1] = slot
		end
	end
	return slots
end

-- Moves an FD macro between the account and character slots. The game can't move a macro, so it
-- is deleted and made again, then put back on every action button that held it. Returns the new
-- index and how many buttons were refilled; if the game refuses the new one, the old is restored.
local function Move(def, index, body, place)
	local buttons = ButtonsWith(def.name)
	local _, icon = GetMacroInfo(index)
	local from = PlaceOf(index)
	body = Norm(body)
	DeleteMacro(index)
	local function Make(where)
		local ok, made = pcall(CreateMacro, def.name, icon or def.icon or ICON, body, where == "character")
		return ok and type(made) == "number" and made > 0 and made or nil
	end
	local created = Make(place)
	if not created then
		created, place = Make(from), from -- the game refused: put it back where it was
	end
	local refilled = 0
	if created and PickupMacro and PlaceAction and ClearCursor then
		for _, slot in ipairs(buttons) do
			ClearCursor()
			PickupMacro(created)
			PlaceAction(slot)
			ClearCursor()
			refilled = refilled + 1
		end
	end
	return created, place, refilled
end

-- Brings the FD macros in line with the settings. Out of combat only (the client refuses macro
-- changes in combat); asked for in combat, it runs as the fight ends.
function M.Sync()
	if not (ns.isDruid and CreateMacro and EditMacro and DeleteMacro and GetMacroInfo and GetNumMacros) then
		return false -- profiles are shared across characters; druid macros stay on druids
	end
	if InCombatLockdown() then
		pending = true
		return false
	end
	pending = false
	local result = { created = 0, updated = 0, removed = 0, skipped = 0, moved = 0, buttons = 0, full = false }
	local function One(def)
		local index, current, oldName = Existing(def)
		local record = Recorded(def.key)
		local ours = index and record and Same(current, record)
		if oldName and ours then
			-- Renamed: same slot, new name (EditMacro returns the slot it ends up in).
			index = EditMacro(index, def.name, nil, current) or index
			result.updated = result.updated + 1
		end
		if index and record and not ours then
			result.skipped = result.skipped + 1 -- you edited it: hands off
		elseif M.IsWanted(def.key) then
			local place = M.Place(def.key)
			if ours and PlaceOf(index) ~= place then
				if SlotsFree(place) > 0 then
					local now, refilled
					index, now, refilled = Move(def, index, current, place)
					Record(def.key, Norm(current), now)
					result.moved = result.moved + 1
					result.buttons = result.buttons + refilled
				else
					result.full = true
				end
			end
			local body = Body(def)
			if body then
				if not index then
					if SlotsFree(place) > 0 then
						local created = CreateMacro(def.name, def.icon or ICON, body, place == "character")
						if type(created) == "number" and created > 0 then
							Record(def.key, body, place)
							result.created = result.created + 1
						end
					else
						result.full = true
					end
				elseif Same(current, body) then
					Record(def.key, body, PlaceOf(index)) -- adopt an identical macro (e.g. after a reinstall)
				elseif ours then
					EditMacro(index, nil, nil, body)
					Record(def.key, body, PlaceOf(index))
					result.updated = result.updated + 1
				else
					result.skipped = result.skipped + 1 -- a macro of yours already has this name
				end
			end
		elseif ours then
			DeleteMacro(index)
			Record(def.key, nil)
			result.removed = result.removed + 1
		end
	end
	for _, def in ipairs(M.LIST) do
		-- One bad macro (or a client refusal) never stops the rest.
		local ok, err = pcall(One, def)
		if not ok then
			ns.ReportError(err)
		end
	end
	M.lastSync = result
	ns.Fire("FD_MACROS_CHANGED", result)
	return true, result
end

local function Queue()
	if ns.isDruid and ns.db and ns.db.macros.manage then
		ns.Debounce("macros", 1, M.Sync)
	end
end

function M.SetManaged(on)
	local cfg = Config()
	cfg.manage = on and true or false
	if InCombatLockdown() then
		pending = true
		ns.Print(L["macros will update when the fight ends"])
		return
	end
	local _, result = M.Sync()
	M.Report(result)
end

function M.SetWanted(key, on)
	Config().enabled[key] = on and true or false
	if InCombatLockdown() then
		pending = true
		return
	end
	M.Sync()
end

local function SyncAndSayMoves()
	if InCombatLockdown() then
		pending = true
		ns.Print(L["macros will update when the fight ends"])
		return
	end
	local _, result = M.Sync()
	if result and result.moved > 0 then
		ns.Print(L["macros moved: %d, put back on %d action buttons"]:format(result.moved, result.buttons))
	end
	if result and result.full then
		ns.Print(L["no free macro slots there: delete one in /macro to make room"])
	end
end

-- One macro to the account or character slots.
function M.SetPlace(key, place)
	local cfg = Config()
	cfg.places = cfg.places or {}
	cfg.places[key] = place == "character" and "character" or "account"
	SyncAndSayMoves()
end

-- All of them, and the default for ones made later.
function M.SetPlaceForAll(place)
	local cfg = Config()
	cfg.place = place == "character" and "character" or "account"
	cfg.places = {}
	SyncAndSayMoves()
end

function M.Report(result)
	if not result then
		return
	end
	ns.Print(("%s: %d %s, %d %s, %d %s"):format(L["macros"], result.created, L["created"], result.updated, L["updated"], result.removed, L["removed"]))
	if result.moved and result.moved > 0 then
		ns.Print(L["macros moved: %d, put back on %d action buttons"]:format(result.moved, result.buttons))
	end
	if result.full then
		ns.Print(L["no free macro slots there: delete one in /macro to make room"])
	end
	if result.skipped > 0 then
		ns.Print(L["left alone because you edited them:"] .. " " .. result.skipped)
	end
end

-- Overwrites FD macros you edited with ForeverDruid's version again (asked for explicitly).
function M.Restore()
	if InCombatLockdown() then
		ns.Print(L["can't change macros during combat"])
		return 0
	end
	local restored = 0
	for _, def in ipairs(M.LIST) do
		local index, current = Existing(def)
		-- Only macros ForeverDruid wrote: a macro of yours that shares a name is never touched.
		local body = index and Recorded(def.key) and M.IsWanted(def.key) and Body(def)
		if body and not Same(current, body) then
			EditMacro(index, nil, nil, body)
			Record(def.key, body, PlaceOf(index))
			restored = restored + 1
		end
	end
	return restored
end

-- Puts the macro on your cursor to drop on an action bar.
function M.PickUp(key)
	if InCombatLockdown() then
		ns.Print(L["can't pick up macros during combat"])
		return false
	end
	local index = Existing(BY_KEY[key])
	if not index then
		ns.Print(L["that macro doesn't exist yet"])
		return false
	end
	PickupMacro(index)
	return true
end

---------------------------------------------------------------------------
-- FD Reshift's button: a hidden secure button that remembers which form you were last in, using
-- Blizzard's secure state driver (which keeps working in combat). In Cat or Bear Form it leaves
-- the form and tries to shift straight back; if the game still has you shifted it stops, and the
-- next press, now in caster form, shifts back into the form you came from.
---------------------------------------------------------------------------

local reshift
local reshiftPending = false

-- Snippet run by the secure environment whenever your form changes.
local RESHIFT_ON_STATE = [[
	if newstate == "cat" or newstate == "bear" then
		self:SetAttribute("fdlast", newstate)
		self:SetAttribute("macrotext", self:GetAttribute("fdout-" .. newstate))
	else
		self:SetAttribute("macrotext", self:GetAttribute("fdback-" .. (self:GetAttribute("fdlast") or "cat")))
	end
]]

function M.SetupReshift()
	if InCombatLockdown() or not ns.isDruid then
		return false
	end
	local cat, bear = FormIndex("cat"), FormIndex("bear")
	if not reshift then
		reshift = CreateFrame("Button", "ForeverDruidReshift", UIParent, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
		reshift:SetSize(1, 1)
		reshift:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -50, -50) -- off screen, invisible
		reshift:SetAlpha(0)
		reshift:EnableMouse(false)
		reshift:RegisterForClicks("AnyUp", "AnyDown")
		reshift:SetAttribute("type", "macro")
		-- /click from a macro arrives as a key release; act on it.
		reshift:SetAttribute("useOnKeyDown", false)
		reshift:SetAttribute("_onstate-form", RESHIFT_ON_STATE)
		M.reshift = reshift
	end
	local catName, bearName = S("catForm"), S(ns.BearFormKey())
	reshift:SetAttribute("fdout-cat", catName and ("/cancelform [nostealth]\n/stopmacro [form]\n/cast !" .. catName) or "")
	reshift:SetAttribute("fdout-bear", bearName and ("/cancelform\n/stopmacro [form]\n/cast !" .. bearName) or "")
	reshift:SetAttribute("fdback-cat", catName and ("/cast !" .. catName) or "")
	reshift:SetAttribute("fdback-bear", bearName and ("/cast !" .. bearName) or "")
	local states = {}
	if bear then
		states[#states + 1] = ("[form:%d] bear"):format(bear)
	end
	if cat then
		states[#states + 1] = ("[form:%d] cat"):format(cat)
	end
	states[#states + 1] = "none"
	if RegisterStateDriver then
		RegisterStateDriver(reshift, "form", table.concat(states, "; "))
	end
	return true
end

local function QueueReshift()
	if ns.isDruid then
		ns.Debounce("reshift", 1, function()
			if not M.SetupReshift() then
				reshiftPending = true
			end
		end)
	end
end

ns.Listen("FD_SPELLS_CHANGED", QueueReshift)
ns.On("UPDATE_SHAPESHIFT_FORMS", QueueReshift)
ns.On("PLAYER_REGEN_ENABLED", function()
	if reshiftPending then
		reshiftPending = false
		QueueReshift()
	end
end)

ns.Listen("FD_SPELLS_CHANGED", Queue)
-- The potion, Healthstone and Spirit-weapon macros follow what's in your bags.
ns.On("BAG_UPDATE_DELAYED", function()
	local cfg = ns.db and ns.db.macros
	if cfg and (M.IsWanted("bearPotion") or M.IsWanted("stonePotion") or M.IsWanted("spiritInnervate")) then
		Queue()
	end
end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function()
	if ns.db and M.IsWanted("spiritInnervate") then
		Queue()
	end
end)
-- Learning a form can renumber your stance bar; the form-numbered macros follow it.
ns.On("UPDATE_SHAPESHIFT_FORMS", Queue)
ns.Listen("FD_LOGIN", function()
	if ns.isDruid then
		Queue()
	end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
	if pending then
		ns.Debounce("macros", 0.5, M.Sync)
	end
end)
