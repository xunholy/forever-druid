-- Levelling helpers: reagent restock at vendors, a trainer reminder after levelling up, and
-- reminders for the Bear Form (10) and Cat Form (20) class quests while you don't have the form.
-- The trainer and quest reminders appear in the Reminders row (out of combat).

local _, ns = ...
local L = ns.L

local M = {}
ns.leveling = M

---------------------------------------------------------------------------
-- Reagent restock
---------------------------------------------------------------------------

-- Rebirth rank -> its seed; Gift of the Wild rank -> its reagent.
local SEED_FOR_REBIRTH = { [20484] = 17034, [20739] = 17035, [20742] = 17036, [20747] = 17037, [20748] = 17038 }
local REAGENT_FOR_GIFT = { [21849] = 17021, [21850] = 17026 }

-- The reagent item each known spell needs, falling back to the highest one listed for it.
function M.WantedReagents()
	local cfg = ns.db.restock
	local wanted = {}
	local rebirth = ns.KnownSpell("rebirth")
	if rebirth then
		wanted[#wanted + 1] = { item = SEED_FOR_REBIRTH[rebirth], fallback = ns.REAGENTS.rebirth, target = cfg.seeds }
	end
	local gift = ns.KnownSpell("giftOfTheWild")
	if gift then
		wanted[#wanted + 1] = { item = REAGENT_FOR_GIFT[gift], fallback = ns.REAGENTS.giftOfTheWild, target = cfg.thornroot }
	end
	return wanted
end

local function MerchantIndexFor(itemIDs)
	local byItem = {}
	for i = 1, GetMerchantNumItems() do
		local id = GetMerchantItemID(i)
		if id then
			byItem[id] = i
		end
	end
	-- Prefer the last (highest-rank) reagent in the list that this vendor sells.
	for n = #itemIDs, 1, -1 do
		if byItem[itemIDs[n]] then
			return byItem[itemIDs[n]], itemIDs[n]
		end
	end
end

-- Buys what's missing up to each target. Returns a list of { item=, count= } actually bought.
function M.Restock()
	local bought = {}
	if not (ns.isDruid and ns.db.restock.enabled and GetMerchantNumItems and BuyMerchantItem) or InCombatLockdown() then
		return bought
	end
	for _, want in ipairs(M.WantedReagents()) do
		local candidates = want.item and { want.item } or want.fallback
		local index, itemID = MerchantIndexFor(candidates)
		if not index and want.item then
			index, itemID = MerchantIndexFor(want.fallback)
		end
		local have = itemID and ns.modules.reminders.CountItems({ itemID }) or 0
		local missing = (want.target or 0) - have
		if index and missing > 0 then
			local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(index)
			if info and info.isPurchasable ~= false and not info.hasExtendedCost then
				local each = (info.price or 0) / math.max(info.stackCount or 1, 1)
				local affordable = each > 0 and math.floor((GetMoney() or 0) / each) or missing
				local available = (info.numAvailable and info.numAvailable >= 0) and info.numAvailable or missing
				local count = math.min(missing, affordable, available)
				if count > 0 then
					local ok = pcall(BuyMerchantItem, index, count)
					if ok then
						bought[#bought + 1] = { item = itemID, count = count, name = info.name }
					end
				end
			end
		end
	end
	if #bought > 0 then
		local parts = {}
		for _, b in ipairs(bought) do
			parts[#parts + 1] = b.count .. "x " .. tostring(b.name or b.item)
		end
		ns.Print(L["restocked"] .. " " .. table.concat(parts, ", "))
	end
	return bought
end

ns.On("MERCHANT_SHOW", function()
	-- Let the merchant's list fill in first.
	C_Timer.After(0.3, function()
		local ok, err = pcall(M.Restock)
		if not ok then
			ns.ReportError(err)
		end
	end)
end)

---------------------------------------------------------------------------
-- Trainer and class quest reminders
---------------------------------------------------------------------------

local TRAINER_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function TrainerState()
	ns.global.trainer = ns.global.trainer or {}
	return ns.global.trainer
end

-- Classic druids get new ranks at even levels.
function M.NoteLevel(level)
	if type(level) == "number" and level % 2 == 0 then
		TrainerState()[ns.charKey] = level
		if ns.db.modules.reminders.trainer then
			ns.Print(("%s %d: %s"):format(L["Level"], level, L["new ranks may be waiting at your druid trainer"]))
		end
	end
	if level == 10 and not ns.IsKnown("bearForm") then
		ns.Print(L["Bear Form is a class quest from level 10: ask your druid trainer"])
	elseif level == 20 and not ns.IsKnown("catForm") then
		ns.Print(L["Cat Form is a class quest from level 20: ask your druid trainer"])
	end
end

-- Extra entries for the Reminders row (not clickable).
function M.Reminders(cfg)
	local list = {}
	local level = tonumber(ns.SafeReadable(UnitLevel, "player")) or 0
	if cfg.trainer and TrainerState()[ns.charKey] then
		list[#list + 1] = { label = L["Trainer"], sampleIcon = TRAINER_ICON,
			tip = L["You levelled up: new ranks may be waiting at your druid trainer. Clears when you visit one."] }
	end
	if cfg.formQuests then
		if level >= 10 and not ns.IsKnown("bearForm") then
			list[#list + 1] = { label = L["Bear Form"], sampleIcon = ns.SpellIcon(5487),
				tip = L["Bear Form comes from a class quest at level 10. Your druid trainer starts it."] }
		end
		if level >= 20 and not ns.IsKnown("catForm") then
			list[#list + 1] = { label = L["Cat Form"], sampleIcon = ns.SpellIcon(768),
				tip = L["Cat Form comes from a class quest at level 20. Your druid trainer starts it."] }
		end
	end
	return list
end

ns.On("PLAYER_LEVEL_UP", function(_, level)
	if ns.isDruid then
		M.NoteLevel(tonumber(level))
		ns.Fire("FD_REMINDERS_CHANGED")
	end
end)

ns.On("TRAINER_SHOW", function()
	if ns.isDruid and TrainerState()[ns.charKey] then
		TrainerState()[ns.charKey] = nil
		ns.Fire("FD_REMINDERS_CHANGED")
	end
end)
