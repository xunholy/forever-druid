-- Item tooltips: what an item is worth to a druid, and the change against what you're wearing in
-- that slot. Cat attack power is 2 per Strength plus 1 per Agility, Bear is 2 per Strength (the
-- Classic druid formulas), plus any attack power the item gives in forms; healing adds healing
-- and spell power. Item stats are ordinary readable data.

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

local function Stat(stats, key)
	local v = stats[key]
	return type(v) == "number" and v or 0
end

-- { cat=, bear=, healing= } for an item link, or nil.
function M.Values(link)
	if not (link and C_Item and C_Item.GetItemStats) then
		return nil
	end
	local ok, stats = pcall(C_Item.GetItemStats, link)
	if not ok or type(stats) ~= "table" or ns.IsSecret(stats) then
		return nil
	end
	local str = Stat(stats, "ITEM_MOD_STRENGTH_SHORT")
	local agi = Stat(stats, "ITEM_MOD_AGILITY_SHORT")
	local ap = Stat(stats, "ITEM_MOD_ATTACK_POWER_SHORT") + Stat(stats, "ITEM_MOD_FERAL_ATTACK_POWER_SHORT")
	local heal = Stat(stats, "ITEM_MOD_SPELL_HEALING_DONE_SHORT") + Stat(stats, "ITEM_MOD_SPELL_POWER_SHORT")
	return { cat = 2 * str + agi + ap, bear = 2 * str + ap, healing = heal }
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
	local function Add(label, value, was, show)
		if not show then
			return
		end
		local text = ("%s +%d"):format(label, value)
		local r, g, b = 0.9, 0.8, 0.5
		if was then
			local delta = value - was
			if delta ~= 0 then
				text = text .. (" (%s%d)"):format(delta > 0 and "+" or "", delta)
				if delta > 0 then
					r, g, b = 0.3, 1, 0.3
				else
					r, g, b = 1, 0.35, 0.35
				end
			end
		end
		lines[#lines + 1] = { text, r, g, b }
	end
	Add(L["Cat attack power"], values.cat, base and base.cat, values.cat > 0 or (base and base.cat > 0))
	Add(L["Bear attack power"], values.bear, base and base.bear, values.bear > 0 or (base and base.bear > 0))
	Add(L["Healing"], values.healing, base and base.healing, values.healing > 0 or (base and base.healing > 0))
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
