-- Item tooltips: what an item's stats come to for a druid, and the change against what you're
-- wearing in that slot. Primary stats and ratings are turned into what they do: Agility into crit,
-- dodge, armor and Cat attack power; Intellect into mana and spell crit; Stamina into health;
-- crit, hit, haste, dodge and defense ratings into their percentages. Cat attack power is 2 per
-- Strength plus 1 per Agility, Bear is 2 per Strength (the Classic druid formulas), plus any attack
-- power the item gives in forms.
--
-- The conversions come from the client (the same calls the character sheet uses), so they follow
-- your level. Item stats are always readable; the conversions are hidden whenever Forever restricts
-- unit stats, and then the raw stat is shown instead (Agility +6 rather than its crit).

local _, ns = ...
local L = ns.L

local M = {}
ns.tooltips = M

-- equip location -> inventory slot to compare against
local SLOT_FOR = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16,
	INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17,
	INVTYPE_SHIELD = 17, INVTYPE_RELIC = 18, INVTYPE_RANGED = 18,
}

-- GetItemStats keys summed into each raw stat.
local RAW = {
	str = { "ITEM_MOD_STRENGTH_SHORT" },
	agi = { "ITEM_MOD_AGILITY_SHORT" },
	sta = { "ITEM_MOD_STAMINA_SHORT" },
	int = { "ITEM_MOD_INTELLECT_SHORT" },
	spi = { "ITEM_MOD_SPIRIT_SHORT" },
	ap = { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "ITEM_MOD_MELEE_ATTACK_POWER_SHORT" },
	crit = { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT" },
	spellCrit = { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT" },
	hit = { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT" },
	spellHit = { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT" },
	haste = { "ITEM_MOD_HASTE_RATING_SHORT" },
	dodge = { "ITEM_MOD_DODGE_RATING_SHORT" },
	defense = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
	armor = { "RESISTANCE0_NAME", "ITEM_MOD_EXTRA_ARMOR_SHORT" },
	health = { "ITEM_MOD_HEALTH_SHORT" },
	mana = { "ITEM_MOD_MANA_SHORT" },
	healing = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_POWER_SHORT" },
	spellDamage = { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_SPELL_POWER_SHORT" },
	mp5 = { "ITEM_MOD_MANA_REGENERATION_SHORT" },
}

-- Character-sheet constants (Camelot PaperDollFrameConstants / PaperDollFrameStats).
local STAT_AGI, STAT_INT = 2, 4
local ARMOR_PER_AGILITY = 2
local CR = { crit = 9, spellCrit = 11, hit = 6, spellHit = 8, haste = 18, dodge = 3, defense = 2 }

local function Num(v)
	if v == nil or ns.IsSecret(v) or type(v) ~= "number" then
		return nil
	end
	return v
end

-- Raw stats of an item link, or nil if it has none we can read.
function M.Stats(link)
	if not (link and C_Item and C_Item.GetItemStats) then
		return nil
	end
	local ok, stats = pcall(C_Item.GetItemStats, link)
	if not ok or type(stats) ~= "table" or ns.IsSecret(stats) then
		return nil
	end
	local raw = {}
	for name, keys in pairs(RAW) do
		local total = 0
		for _, key in ipairs(keys) do
			total = total + (Num(stats[key]) or 0)
		end
		raw[name] = total
	end
	return raw
end

-- The client's conversion of `amount` of a stat or rating, as the change from zero; nil when hidden.
local function FromStat(fn, index, amount, scale)
	if amount == 0 then
		return 0
	end
	local at = Num(ns.SafeReadable(fn, index, amount))
	local zero = Num(ns.SafeReadable(fn, index, 0))
	if at == nil or zero == nil then
		return nil
	end
	return (at - zero) * (scale or 1)
end

local function FromRating(rating, amount)
	if amount == 0 then
		return 0
	end
	return Num(ns.SafeReadable(GetCombatRatingBonusForCombatRatingValue, CR[rating], amount))
end

-- Dodge per point of Agility, from your current dodge-from-Agility and Agility (the client has no
-- "dodge from N Agility" call). nil when hidden or you have no Agility.
local function DodgePerAgility()
	local fromAgi = Num(ns.SafeReadable(GetDodgeChanceFromAttribute))
	if not (fromAgi and UnitStat) then
		return nil
	end
	local ok, _, effective = pcall(UnitStat, "player", STAT_AGI)
	effective = ok and Num(effective)
	if not effective or effective <= 0 then
		return nil
	end
	return fromAgi * 100 / effective
end

-- Every line the tooltip can show, in order: key, label, format ("%d" or "%.1f%%"), and how to
-- work it out from the raw stats. A conversion that comes back nil drops the line and shows the
-- raw stat instead (see RAW_LABELS).
local LINES = {
	{ "cat", "Cat attack power", "int" },
	{ "bear", "Bear attack power", "int" },
	{ "critPct", "Crit chance", "pct" },
	{ "hitPct", "Hit chance", "pct" },
	{ "hastePct", "Haste", "pct" },
	{ "health", "Health", "int" },
	{ "armor", "Armor", "int" },
	{ "dodgePct", "Dodge chance", "pct" },
	{ "defense", "Defense", "int" },
	{ "mana", "Mana", "int" },
	{ "spellCritPct", "Spell crit chance", "pct" },
	{ "spellHitPct", "Spell hit chance", "pct" },
	{ "healing", "Healing", "int" },
	{ "spellDamage", "Spell damage", "int" },
	{ "mp5", "Mana per 5 sec", "int" },
	{ "spi", "Spirit", "int" },
}
-- Shown when a conversion is hidden: the stat itself.
local RAW_LINES = {
	{ "agi", "Agility" }, { "sta", "Stamina" }, { "int", "Intellect" }, { "crit", "Crit rating" },
	{ "hit", "Hit rating" }, { "haste", "Haste rating" }, { "dodge", "Dodge rating" },
	{ "defense", "Defense rating" },
}

-- What an item's stats come to: { cat=, bear=, critPct=, ... } plus raw.<stat> for any stat whose
-- conversion was hidden. nil if the item has no readable stats.
function M.Values(link)
	local r = M.Stats(link)
	if not r then
		return nil
	end
	local v, rawShown = {}, {}
	local function Need(stat)
		rawShown[stat] = r[stat]
	end
	local function Sum(...)
		local total = 0
		for i = 1, select("#", ...) do
			local part = select(i, ...)
			if part == nil then
				return nil
			end
			total = total + part
		end
		return total
	end

	v.cat = 2 * r.str + r.agi + r.ap
	v.bear = 2 * r.str + r.ap

	local agiCrit = FromStat(GetCritChanceFromStat, STAT_AGI, r.agi, 100)
	local critFromRating = FromRating("crit", r.crit)
	v.critPct = Sum(agiCrit, critFromRating)
	v.hitPct = FromRating("hit", r.hit)
	v.hastePct = FromRating("haste", r.haste)

	local hpPer = Num(ns.SafeReadable(UnitHPPerStamina, "player"))
	v.health = r.sta == 0 and r.health or (hpPer and r.sta * hpPer + r.health)

	v.armor = r.armor + r.agi * ARMOR_PER_AGILITY
	local perAgi = r.agi == 0 and 0 or DodgePerAgility()
	local dodgeRating = FromRating("dodge", r.dodge)
	v.dodgePct = Sum(perAgi and r.agi * perAgi, dodgeRating)
	v.defense = FromRating("defense", r.defense)

	local manaPerInt = type(MANA_PER_INTELLECT) == "number" and MANA_PER_INTELLECT > 0 and MANA_PER_INTELLECT or 15
	v.mana = r.int * manaPerInt + r.mana
	local intCrit = FromStat(GetSpellCritChanceFromStat, STAT_INT, r.int, 100)
	local spellCritFromRating = FromRating("spellCrit", r.spellCrit)
	v.spellCritPct = Sum(intCrit, spellCritFromRating)
	v.spellHitPct = FromRating("spellHit", r.spellHit)

	v.healing, v.spellDamage, v.mp5, v.spi = r.healing, r.spellDamage, r.mp5, r.spi

	-- Hidden conversions: show the stat behind them instead.
	if agiCrit == nil or (r.agi ~= 0 and perAgi == nil) then
		Need("agi")
	end
	if critFromRating == nil or spellCritFromRating == nil then
		Need("crit")
	end
	if v.hitPct == nil or v.spellHitPct == nil then
		Need("hit")
	end
	if v.hastePct == nil then
		Need("haste")
	end
	if v.health == nil then
		Need("sta")
	end
	if dodgeRating == nil then
		Need("dodge")
	end
	if v.defense == nil then
		Need("defense")
	end
	if intCrit == nil then
		Need("int")
	end
	v.raw = rawShown
	return v
end

local function EquippedLink(link)
	if not (C_Item and C_Item.GetItemInfoInstant and GetInventoryItemLink) then
		return nil
	end
	local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, link)
	local slot = ok and SLOT_FOR[equipLoc]
	if not slot then
		return nil
	end
	local equipped = GetInventoryItemLink("player", slot)
	if equipped == link then
		return nil -- hovering what you're wearing: no comparison
	end
	return equipped, true
end

-- Rounded the way it's shown: whole numbers, or percentages to one decimal.
local function Round(kind, value)
	local step = kind == "pct" and 10 or 1
	local sign = value < 0 and -1 or 1
	return sign * math.floor(math.abs(value) * step + 0.5) / step
end

local function Signed(kind, value)
	value = Round(kind, value)
	local text = kind == "pct" and ("%.1f%%"):format(math.abs(value)) or ("%d"):format(math.abs(value))
	return (value < 0 and "-" or "+") .. text
end

-- Tooltip lines as { text, r, g, b }.
function M.Lines(link)
	local cfg = ns.db and ns.db.tooltips
	local values = cfg and cfg.enabled and M.Values(link)
	if not values then
		return {}
	end
	local current = cfg.compare and EquippedLink(link)
	local base = current and M.Values(current) or nil
	local lines = {}
	-- One line: the item's value, then the change from what you wear (green better, red worse).
	-- Skipped when both round to nothing; a change too small to show leaves the line uncoloured.
	local function Add(label, kind, value, was)
		value = value or 0
		if Round(kind, value) == 0 and (was == nil or Round(kind, was) == 0) then
			return
		end
		local text = ("%s %s"):format(label, Signed(kind, value))
		local r, g, b = 0.9, 0.8, 0.5
		if was then
			local delta = Round(kind, value - was)
			if delta ~= 0 then
				text = text .. (" (%s)"):format(Signed(kind, delta))
				if delta > 0 then
					r, g, b = 0.3, 1, 0.3
				else
					r, g, b = 1, 0.35, 0.35
				end
			end
		end
		lines[#lines + 1] = { text, r, g, b }
	end
	for _, line in ipairs(LINES) do
		local key, label, kind = line[1], line[2], line[3]
		local value = values[key]
		local was = base and base[key]
		if value ~= nil or was ~= nil then
			Add(L[label], kind, value, base and (was or 0) or nil)
		end
	end
	for _, line in ipairs(RAW_LINES) do
		local key, label = line[1], line[2]
		local value = values.raw[key]
		local was = base and base.raw[key]
		if value ~= nil or was ~= nil then
			Add(L[label], "int", value, base and (was or 0) or nil)
		end
	end
	return lines
end

local function OnItem(tooltip)
	-- The main and linked-item tooltips only, not the side-by-side comparison ones.
	if not (ns.isDruid and tooltip and tooltip.GetItem) or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
		return
	end
	local ok, _, link = pcall(tooltip.GetItem, tooltip)
	if not ok or ns.IsSecret(link) or type(link) ~= "string" then
		return
	end
	local lines = M.Lines(link)
	if #lines == 0 then
		return
	end
	tooltip:AddLine(ns.DISPLAY_NAME, 1, 0.49, 0.04)
	for _, line in ipairs(lines) do
		tooltip:AddLine(line[1], line[2], line[3], line[4])
	end
end
M.OnItem = OnItem

ns.Listen("FD_LOGIN", function()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
			local ok, err = pcall(OnItem, tooltip)
			if not ok then
				ns.ReportError(err)
			end
		end)
	end
end)
