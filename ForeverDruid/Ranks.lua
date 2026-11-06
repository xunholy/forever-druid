-- Keeps the spells on your action bars at their highest rank.
--
-- Forever has Classic spell ranks, and an action button keeps the rank it was given: learn
-- Rejuvenation (Rank 4) and every button still casts Rank 3. After you learn spells (and at login),
-- out of combat, this swaps any lower rank on your bars for the highest rank you know, in the same
-- slot. Spells you list with /fd ranks keep <spell> are left alone, for deliberate downranking.
-- Macros need nothing: "/cast <spell>" always uses the highest rank.

local _, ns = ...
local L = ns.L

local M = {}
ns.ranks = M

local MAX_SLOTS = 180
M.stats = { scans = 0, upgraded = 0, deferred = 0 }
local pending = false

local function Config()
	return ns.db.ranks
end

local function RankText(spellID)
	local text = C_Spell.GetSpellSubtext and ns.SafeReadable(C_Spell.GetSpellSubtext, spellID)
	return type(text) == "string" and text ~= "" and text or nil
end

-- What to put in each slot that holds a lower rank: { {slot=, from=, to=, name=}, ... }.
-- Reads only; safe to call any time.
function M.Plan()
	local plan = {}
	if not (GetActionInfo and C_Spell and C_Spell.GetSpellName) then
		return plan
	end
	local keep = Config().keep
	for slot = 1, MAX_SLOTS do
		local kind, id = GetActionInfo(slot)
		if not ns.IsSecret(kind) and kind == "spell" and not ns.IsSecret(id) and type(id) == "number" then
			local highest = C_ActionBar and C_ActionBar.IsHighestSpellRank
				and ns.SafeReadable(C_ActionBar.IsHighestSpellRank, id)
			if highest ~= true then
				local name = ns.SafeReadable(C_Spell.GetSpellName, id)
				local best = type(name) == "string" and ns.KnownSpellByName(name)
				-- Only ever move up: the replacement must itself be your highest rank.
				local bestIsTop = not (C_ActionBar and C_ActionBar.IsHighestSpellRank)
					or ns.SafeReadable(C_ActionBar.IsHighestSpellRank, best) == true
				if best and best ~= id and bestIsTop and not keep[strlower(name)] then
					plan[#plan + 1] = { slot = slot, from = id, to = best, name = name }
				end
			end
		end
	end
	return plan
end

local function CursorBusy()
	return GetCursorInfo and GetCursorInfo() ~= nil
end

-- Applies the plan. Out of combat only, and never while you're dragging something.
function M.Upgrade(quiet)
	if not ns.isDruid then
		return 0
	end
	if InCombatLockdown() or CursorBusy() then
		pending = true
		M.stats.deferred = M.stats.deferred + 1
		return 0, true
	end
	pending = false
	M.stats.scans = M.stats.scans + 1
	local plan = M.Plan()
	local done, names = 0, {}
	for _, step in ipairs(plan) do
		local ok = pcall(function()
			ClearCursor()
			C_Spell.PickupSpell(step.to)
			-- Never place an empty or unexpected cursor: that could clear the button.
			if GetCursorInfo() ~= "spell" then
				error("pickup failed")
			end
			PlaceAction(step.slot)
			ClearCursor() -- the old rank lands on the cursor; drop it
			local kind, now = GetActionInfo(step.slot)
			if kind ~= "spell" or now ~= step.to then
				-- Something went wrong: put the old rank back where it was.
				C_Spell.PickupSpell(step.from)
				if GetCursorInfo() == "spell" then
					PlaceAction(step.slot)
				end
				ClearCursor()
				error("slot didn't take the new rank")
			end
		end)
		if ok then
			done = done + 1
			if not names[step.name] then
				names[step.name] = RankText(step.to) or ""
				names[#names + 1] = step.name
			end
		else
			pcall(ClearCursor)
		end
	end
	M.stats.upgraded = M.stats.upgraded + done
	if done > 0 and not quiet then
		local parts = {}
		for _, name in ipairs(names) do
			local rank = names[name]
			parts[#parts + 1] = rank ~= "" and (name .. " (" .. rank .. ")") or name
		end
		ns.Print(L["action bars updated to your highest ranks:"] .. " " .. table.concat(parts, ", "))
	end
	return done
end

local function Queue()
	if ns.isDruid and ns.db and Config().auto then
		ns.Debounce("ranks", 1.5, M.Upgrade)
	end
end

-- /fd ranks keep|unkeep <spell>: leave a spell at whatever rank you put on your bars.
function M.SetKept(name, kept)
	if not name or name == "" then
		return false
	end
	Config().keep[strlower(name)] = kept and true or nil
	return true
end

function M.KeptList()
	local list = {}
	for name in pairs(Config().keep) do
		list[#list + 1] = name
	end
	table.sort(list)
	return list
end

ns.Listen("FD_SPELLS_CHANGED", Queue)
ns.On("LEARNED_SPELL_IN_SKILL_LINE", Queue)
ns.On("PLAYER_REGEN_ENABLED", function()
	if pending then
		ns.Debounce("ranks", 1, M.Upgrade)
	end
end)
-- Dropping what you were dragging frees the cursor for a deferred upgrade.
ns.On("CURSOR_CHANGED", function()
	if pending and not InCombatLockdown() then
		ns.Debounce("ranks", 1, M.Upgrade)
	end
end)
