-- Druid spell catalogue and spellbook lookup.
--
-- Forever mixes Classic spells with new ones, and ranks have different spell IDs, so spells are
-- matched by name against the player's spellbook. Each entry is { englishName, candidateIDs... };
-- the first ID the client knows supplies the localized name. IDs marked "probe" were confirmed from
-- a live Forever spellbook (1.60.1.70790).

local _, ns = ...

local SPELLS = {
	-- Forms
	catForm = { "Cat Form", 768 },
	bearForm = { "Bear Form", 5487 }, -- probe
	direBearForm = { "Dire Bear Form", 9634 },
	moonkinForm = { "Moonkin Form", 24858 },
	treeForm = { "Tree of Life", 33891 },
	travelForm = { "Travel Form", 783 },
	aquaticForm = { "Aquatic Form", 1066 },

	-- Utility and defensives
	innervate = { "Innervate", 29166 },
	rebirth = { "Rebirth", 20484 },
	revive = { "Revive", 437138 }, -- probe (Forever)
	barkskin = { "Barkskin", 22812 },
	naturesGrasp = { "Nature's Grasp", 16689 }, -- probe
	dash = { "Dash", 1850 },
	prowl = { "Prowl", 5215 },

	-- Feral
	tigersFury = { "Tiger's Fury", 5217 },
	shiftingPower = { "Shifting Power", 1322605 },
	feralCharge = { "Feral Charge", 16979 },
	faerieFireFeral = { "Faerie Fire (Feral)", 16857 },
	enrage = { "Enrage", 5229 }, -- probe
	frenziedRegeneration = { "Frenzied Regeneration", 22842 },
	bash = { "Bash", 5211 }, -- probe
	challengingRoar = { "Challenging Roar", 5209 },
	growl = { "Growl", 6795 }, -- probe
	primalBite = { "Primal Bite", 407995 },

	-- Balance and Restoration
	hurricane = { "Hurricane", 16914 },
	starfall = { "Starfall", 48505 },
	forceOfNature = { "Force of Nature", 33831 },
	naturesSwiftness = { "Nature's Swiftness", 17116 },
	swiftmend = { "Swiftmend", 18562 },
	tranquility = { "Tranquility", 740 },

	-- Buffs we cast
	markOfTheWild = { "Mark of the Wild", 1126, 5232 }, -- 5232 probe (rank 2)
	giftOfTheWild = { "Gift of the Wild", 21849 },
	thorns = { "Thorns", 467, 782 }, -- 782 probe (rank 2)
	omenOfClarity = { "Omen of Clarity", 16864 },
	-- Used by the macro manager.
	rejuvenation = { "Rejuvenation", 774 },
	regrowth = { "Regrowth", 8936 },
	healingTouch = { "Healing Touch", 5185 },
	maul = { "Maul", 6807 },
	claw = { "Claw", 1082 },
	entanglingRoots = { "Entangling Roots", 339 },
	hibernate = { "Hibernate", 2637 },
	ravage = { "Ravage", 6785 },
	-- Debuffs worth keeping on a target (missing-debuff warning).
	faerieFire = { "Faerie Fire", 770 },
	demoralizingRoar = { "Demoralizing Roar", 99 },
	moonfire = { "Moonfire", 8921 },
	insectSwarm = { "Insect Swarm", 5570 },
	rake = { "Rake", 1822 },
	rip = { "Rip", 1079 },

	-- Skyborne racials (probe)
	readLeyline = { "Read Leyline", 1259705 },
	walkOnAir = { "Walk on Air", 1259416 },
}
ns.SPELLS = SPELLS

-- Auras that are not spells in the spellbook, or whose aura ID differs from the spell.
ns.AURAS = {
	clearcasting = { "Clearcasting", 16870 },
	naturesGrace = { "Nature's Grace", 16886 }, -- Balance proc: next spell casts faster
	pounceBleed = { "Pounce Bleed", 9007 },
	attuned = { "Attuned", 1259691 }, -- probe: Skyborne buff from Read Leyline at a ley line
}

-- Reagents (Classic item IDs; the probe reports the counts so changes in Forever show up).
ns.REAGENTS = {
	rebirth = { 17034, 17035, 17036, 17037, 17038 }, -- Maple, Stranglethorn, Ashwood, Hornbeam, Ironwood Seed
	giftOfTheWild = { 17021, 17026 }, -- Wild Berries, Wild Thornroot
}

local known = {} -- lower-case spell name -> spellID from the spellbook
local passive = {} -- lower-case spell name -> true for passive spellbook entries (talents like Furor)
local nameCache = {}

local function GetSpellNameSafe(spellID)
	if not (C_Spell and C_Spell.GetSpellName) then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, spellID)
	if ok and not ns.IsSecret(name) and name then
		return name
	end
	return nil
end
ns.GetSpellNameSafe = GetSpellNameSafe

-- Returns the name and whether it came from the client (localized) rather than the fallback.
local function ResolveName(entry)
	for i = 2, #entry do
		local name = GetSpellNameSafe(entry[i])
		if name then
			return name, true
		end
	end
	return entry[1], false
end

-- Localized name for a catalogue key (falls back to English).
function ns.SpellName(key)
	local cached = nameCache[key]
	if cached then
		return cached
	end
	local entry = SPELLS[key] or ns.AURAS[key]
	if not entry then
		return nil
	end
	local name, localized = ResolveName(entry)
	-- Only cache client names: early at login spell data may not be loaded yet, and caching the
	-- English fallback then would break matching on non-English clients for the whole session.
	if localized or #entry < 2 then
		nameCache[key] = name
	end
	return name
end

-- Fixed aura spell ID for a catalogue key, when one is known.
function ns.AuraID(key)
	local entry = ns.AURAS[key] or SPELLS[key]
	return entry and entry[2]
end

-- Spell ID the player knows for a catalogue key, or nil.
function ns.KnownSpell(key)
	local name = ns.SpellName(key)
	if not name then
		return nil
	end
	return known[strlower(name)]
end

function ns.IsKnown(key)
	return ns.KnownSpell(key) ~= nil
end

-- Known and something you can actually cast, not a passive spellbook entry. Some Classic buffs
-- can't be cast on Forever (Omen of Clarity), so reminders and click-to-cast check this.
-- Dire Bear Form replaces Bear Form in the spellbook at level 40.
function ns.HasBearForm()
	return ns.IsKnown("direBearForm") or ns.IsKnown("bearForm")
end

function ns.BearFormKey()
	return ns.IsCastable("direBearForm") and "direBearForm" or "bearForm"
end

function ns.IsCastable(key)
	local name = ns.SpellName(key)
	if not name then
		return false
	end
	name = strlower(name)
	return known[name] ~= nil and not passive[name]
end

-- Spell ID the player knows by (any case) name; used for user-added cooldowns.
function ns.KnownSpellByName(name)
	if not name then
		return nil
	end
	return known[strlower(name)]
end

function ns.SpellIcon(spellID)
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
		if ok and not ns.IsSecret(icon) and icon then
			return icon
		end
	end
	return 134400 -- question mark
end

-- Copy of everything found in the spellbook, for the probe.
function ns.KnownSpellList()
	local list = {}
	for name, id in pairs(known) do
		list[name] = id
	end
	return list
end

function ns.PassiveSpellList()
	local list = {}
	for name in pairs(passive) do
		list[name] = known[name]
	end
	return list
end

function ns.ScanSpellbook()
	wipe(known)
	wipe(passive)
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
		return
	end
	local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
	local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if info then
			for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				-- With "Show all spell ranks" the book lists old ranks too: keep only the highest.
				local lowRank = C_SpellBook.IsSpellBookItemLowRank
					and ns.SafeReadable(C_SpellBook.IsSpellBookItemLowRank, slot, bank) == true
				if item and item.spellID and item.name and not item.isOffSpec and not lowRank
					and (spellType == nil or item.itemType == spellType) then
					known[strlower(item.name)] = item.spellID
					if ns.Readable(item.isPassive) == true then
						passive[strlower(item.name)] = true
					end
				end
			end
		end
	end
	ns.spellbookScanned = next(known) ~= nil
	ns.Fire("FD_SPELLS_CHANGED")
end

local function QueueScan()
	ns.Debounce("spellbook", 0.5, ns.ScanSpellbook)
end

ns.On("PLAYER_LOGIN", QueueScan)
ns.On("SPELLS_CHANGED", QueueScan)
ns.On("LEARNED_SPELL_IN_SKILL_LINE", QueueScan)
ns.On("PLAYER_LEVEL_UP", QueueScan)

---------------------------------------------------------------------------
-- Player aura lookup that never compares secret values.
---------------------------------------------------------------------------

-- Returns the AuraData table for a player aura, or nil. `restricted` is true when the client
-- refused to answer (secret in combat), so callers can tell "absent" from "unknown".
-- spellIDs may contain nils (e.g. an unknown rank); every slot up to maxn is tried.
function ns.FindPlayerAura(spellIDs, name)
	local restricted = false
	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		local count = 0
		for index in pairs(spellIDs) do
			if type(index) == "number" and index > count then
				count = index
			end
		end
		for i = 1, count do
			local spellID = spellIDs[i]
			if spellID then
				local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
				if not ok or ns.IsSecret(aura) then
					restricted = true
				elseif aura ~= nil then
					return aura, false
				end
			end
		end
	end
	if name and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
		local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
		if not ok or ns.IsSecret(aura) then
			restricted = true
		elseif aura ~= nil then
			return aura, false
		end
	end
	return nil, restricted
end
