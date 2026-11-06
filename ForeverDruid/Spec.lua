-- Form and talent-line detection, combined into one "role" the modules lay themselves out for.
--
-- Roles: "cat", "bear" (from the current form), otherwise from the talent tree with the most points:
-- "balance", "healer" (Restoration), "feral" (Feral tree while in caster form), or "caster" (no points).

local _, ns = ...

local FORM_KEYS = {
	{ "cat", "catForm" },
	{ "bear", "bearForm" },
	{ "bear", "direBearForm" },
	{ "moonkin", "moonkinForm" },
	{ "tree", "treeForm" },
	{ "travel", "travelForm" },
	{ "aquatic", "aquaticForm" },
}

local function FormFromSpell(spellID)
	if ns.IsSecret(spellID) or not spellID then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, spellID)
	if not ok or ns.IsSecret(name) or not name then
		return nil
	end
	for _, pair in ipairs(FORM_KEYS) do
		if ns.SpellName(pair[2]) == name then
			return pair[1]
		end
	end
	return nil
end

-- Current form key, "caster" when not shapeshifted, or "other" for an unrecognised form.
function ns.GetForm()
	local index = GetShapeshiftForm and GetShapeshiftForm()
	if ns.IsSecret(index) or not index or index == 0 then
		return "caster"
	end
	if GetShapeshiftFormInfo then
		local _, _, _, spellID = GetShapeshiftFormInfo(index)
		return FormFromSpell(spellID) or "other"
	end
	return "other"
end

-- List of shapeshift bar entries, for the probe.
function ns.ShapeshiftForms()
	local forms = {}
	local count = GetNumShapeshiftForms and GetNumShapeshiftForms()
	if ns.IsSecret(count) or not count then
		return forms
	end
	for i = 1, count do
		local _, active, _, spellID = GetShapeshiftFormInfo(i)
		forms[#forms + 1] = {
			index = i,
			spellID = ns.Readable(spellID),
			active = ns.Readable(active),
			form = FormFromSpell(spellID),
		}
	end
	return forms
end

---------------------------------------------------------------------------
-- Talent trees (Forever uses classic-style trees on the retail trait system)
---------------------------------------------------------------------------

local TREE_ORDER = { "balance", "feral", "restoration" }

local function ClassifyTree(displayName, index)
	local lower = displayName and strlower(displayName) or ""
	if lower:find("balance", 1, true) then
		return "balance"
	elseif lower:find("feral", 1, true) then
		return "feral"
	elseif lower:find("resto", 1, true) then
		return "restoration"
	end
	return TREE_ORDER[index]
end

local function ActiveConfigID()
	local spec = C_SpecializationInfo
	if spec and spec.GetCombatConfigIDForSpecGroup and spec.GetActiveSpecGroup then
		local ok, configID = pcall(spec.GetCombatConfigIDForSpecGroup, spec.GetActiveSpecGroup())
		if ok and configID then
			return configID
		end
	end
	if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
		return C_ClassTalents.GetActiveConfigID()
	end
	return nil
end

-- Returns { {key=, name=, spent=}, ... } or nil when the client exposes no tree data.
function ns.GetTalentTrees()
	if not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetGroupDisplayInfoByTreeID) then
		return nil
	end
	local ok, result = pcall(function()
		local configID = ActiveConfigID()
		if not configID then
			return nil
		end
		local config = C_Traits.GetConfigInfo(configID)
		local treeID = config and config.treeIDs and config.treeIDs[1]
		if not treeID then
			return nil
		end
		local displays = C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}
		local groupIDs = {}
		for i, display in ipairs(displays) do
			groupIDs[i] = display.groupID
		end
		local currency = C_Traits.GetGroupCurrencyInfo and C_Traits.GetGroupCurrencyInfo(configID, groupIDs) or {}
		local trees = {}
		for i, display in ipairs(displays) do
			local spent = 0
			for _, group in ipairs(currency) do
				if group.traitNodeGroupID == display.groupID and group.currencyInfos and group.currencyInfos[1] then
					spent = group.currencyInfos[1].spent or 0
				end
			end
			trees[#trees + 1] = { key = ClassifyTree(display.displayName, i), name = display.displayName, spent = spent }
		end
		return trees
	end)
	if ok then
		return result
	end
	return nil
end

-- Tree key with the most points, or nil when nothing is spent.
function ns.PrimaryTree()
	local trees = ns.GetTalentTrees()
	if not trees then
		return nil
	end
	local best, bestSpent = nil, 0
	local spentBy = {}
	for _, tree in ipairs(trees) do
		local spent = ns.Readable(tree.spent) or 0
		spentBy[tree.key] = spent
		if spent > bestSpent then
			best, bestSpent = tree.key, spent
		end
	end
	-- Close call (within 2 points, typical while levelling a split build): most druids in that spot
	-- are fighting in Cat or Bear Form, so prefer Feral over Restoration or Balance.
	local feral = spentBy.feral or 0
	if best and best ~= "feral" and feral > 0 and bestSpent - feral <= 2 then
		return "feral"
	end
	return best
end

-- Unspent talent points from the class tree's currency, or nil if the client won't say.
function ns.UnspentTalentPoints()
	if not (C_Traits and C_Traits.GetTreeCurrencyInfo and C_Traits.GetConfigInfo) then
		return nil
	end
	local ok, unspent = pcall(function()
		local configID = ActiveConfigID()
		local config = configID and C_Traits.GetConfigInfo(configID)
		local treeID = config and config.treeIDs and config.treeIDs[1]
		if not treeID then
			return nil
		end
		local currencies = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
		local first = type(currencies) == "table" and currencies[1]
		return first and ns.Readable(first.quantity)
	end)
	if ok and type(unspent) == "number" then
		return unspent
	end
	return nil
end

-- The role you picked for caster form ("auto" = from your talents). Cat and Bear Form always
-- decide the role themselves.
ns.CASTER_ROLES = { "auto", "healer", "balance", "feral" }

---------------------------------------------------------------------------
-- Role
---------------------------------------------------------------------------

function ns.ComputeRole(form, tree)
	if form == "cat" then
		return "cat"
	elseif form == "bear" then
		return "bear"
	elseif form == "tree" then
		return "healer"
	elseif form == "moonkin" then
		return "balance"
	end
	local chosen = ns.db and ns.db.role
	if chosen and chosen ~= "auto" then
		return chosen
	end
	if tree == "restoration" then
		return "healer"
	elseif tree == "balance" then
		return "balance"
	elseif tree == "feral" then
		return "feral"
	end
	return "caster"
end

ns.form = "caster"
ns.role = "caster"

local function UpdateRole()
	ns.form = ns.GetForm()
	ns.tree = ns.PrimaryTree()
	local role = ns.ComputeRole(ns.form, ns.tree)
	local changed = role ~= ns.role
	ns.role = role
	ns.Fire("FD_FORM_CHANGED", ns.form)
	if changed then
		ns.Fire("FD_ROLE_CHANGED", role)
	end
end
ns.UpdateRole = UpdateRole

local function QueueRole()
	ns.Debounce("role", 0, UpdateRole)
end

ns.On("PLAYER_ENTERING_WORLD", QueueRole)
ns.On("UPDATE_SHAPESHIFT_FORM", QueueRole)
ns.On("UPDATE_SHAPESHIFT_FORMS", QueueRole)
ns.On("TRAIT_CONFIG_UPDATED", QueueRole)
ns.On("PLAYER_TALENT_UPDATE", QueueRole)
ns.On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", QueueRole)
ns.Listen("FD_SPELLS_CHANGED", QueueRole)
