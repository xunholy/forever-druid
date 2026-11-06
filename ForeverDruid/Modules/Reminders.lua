-- Out-of-combat reminders: missing self-buffs, low reagents, and the Skyborne "Attuned" ley line buff.
--
-- Only runs out of combat, when aura data is readable (probe); anything unreadable counts as "fine"
-- so the module never nags on data it can't see. Reminder icons for buffs are secure buttons:
-- click one to cast the buff on yourself. Secure buttons can only be changed out of combat, so the
-- module touches them only then, and hides them as combat starts (before the lockdown applies).

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("reminders", {})

local icons = {}
M.active = {}

local function HasBuff(key)
	local aura, restricted = ns.FindPlayerAura({ ns.KnownSpell(key), ns.AuraID(key) }, ns.SpellName(key))
	return aura ~= nil or restricted
end

local function HasAttuned()
	local aura, restricted = ns.FindPlayerAura({ ns.AuraID("attuned") }, ns.SpellName("attuned"))
	return aura ~= nil or restricted
end

local function CountItems(itemIDs)
	local total = 0
	for _, itemID in ipairs(itemIDs) do
		local count = ns.SafeReadable(C_Item and C_Item.GetItemCount, itemID)
		total = total + (tonumber(count) or 0)
	end
	return total
end
M.CountItems = CountItems

-- Builds the list of reminders as { spellKey=, label=, cast= } without touching frames (testable).
-- `cast` is the spell to cast on click, or nil for reminders that aren't a self-buff.
function M.Collect(cfg)
	local list = {}
	local function Add(spellKey, label, castKey)
		list[#list + 1] = { spellKey = spellKey, label = label, cast = castKey and ns.SpellName(castKey) or nil }
	end

	if cfg.markOfTheWild and ns.IsCastable("markOfTheWild") and not HasBuff("markOfTheWild") and not HasBuff("giftOfTheWild") then
		Add("markOfTheWild", L["Mark"], "markOfTheWild")
	end
	local wantThorns = cfg.thorns or (cfg.thornsInBear and ns.form == "bear")
	if wantThorns and ns.IsCastable("thorns") and not HasBuff("thorns") then
		Add("thorns", L["Thorns"], "thorns")
	end
	-- Only where Omen is a buff you cast. It can't be cast on Forever, so this must not nag there.
	if cfg.omenOfClarity and ns.IsCastable("omenOfClarity") and not HasBuff("omenOfClarity") then
		Add("omenOfClarity", L["Omen"], "omenOfClarity")
	end
	if cfg.reagents then
		local threshold = cfg.reagentThreshold or 2
		if ns.IsKnown("rebirth") then
			local seeds = CountItems(ns.REAGENTS.rebirth)
			if seeds < threshold then
				Add("rebirth", L["Seeds"] .. " " .. seeds)
			end
		end
		if ns.IsKnown("giftOfTheWild") then
			local roots = CountItems(ns.REAGENTS.giftOfTheWild)
			if roots < threshold then
				Add("giftOfTheWild", L["Thornroot"] .. " " .. roots)
			end
		end
	end
	if cfg.attuned and ns.IsCastable("readLeyline") and not HasAttuned() then
		-- Read Leyline only attunes you standing on a ley line, so the click casts it there.
		Add("readLeyline", L["Ley line"], "readLeyline")
	end
	return list
end

local function Suppressed()
	if InCombatLockdown() then
		return true
	end
	if ns.SafeReadable(UnitIsDeadOrGhost, "player") then
		return true
	end
	if ns.SafeReadable(UnitOnTaxi, "player") or ns.SafeReadable(UnitInVehicle, "player") then
		return true
	end
	if ns.db.hideWhenMounted and ns.SafeReadable(IsMounted) then
		return true
	end
	return false
end

local function IconFor(index, parent)
	local frame = icons[index]
	if not frame then
		-- Secure so a click can cast; all attribute and visibility changes happen out of combat.
		frame = CreateFrame("Button", "ForeverDruidReminder" .. index, parent, "SecureActionButtonTemplate")
		frame:RegisterForClicks("AnyUp", "AnyDown")
		local tex = frame:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		frame.icon = tex
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOP", frame, "BOTTOM", 0, -2)
		frame.label = label
		frame:SetScript("OnEnter", function(self)
			if GameTooltip and self.fdTip then
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(self.fdTip)
				if self.fdCast then
					GameTooltip:AddLine(L["Click to cast"] .. " " .. self.fdCast, 1, 1, 1)
				end
				GameTooltip:Show()
			end
		end)
		frame:SetScript("OnLeave", function()
			if GameTooltip then
				GameTooltip:Hide()
			end
		end)
		icons[index] = frame
	end
	return frame
end

local function HideAll()
	for _, frame in ipairs(icons) do
		frame:Hide()
	end
end

function M:Init()
	local cfg = ns.ModuleConfig("reminders")
	self.anchor = ns.CreateAnchor("reminders", cfg.size, cfg.size, { "CENTER", "CENTER", 0, 140 }, L["Reminders"], { secure = true })

	local function Queue()
		if self.enabled then
			ns.Debounce("reminders", 0.3, function()
				if self.enabled then
					self:Refresh()
				end
			end)
		end
	end
	ns.OnUnit("UNIT_AURA", "player", Queue)
	ns.On("BAG_UPDATE_DELAYED", Queue)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if self.hideAfterCombat then
			self.hideAfterCombat = nil
			if not self.enabled then
				HideAll()
				self.anchor:Hide()
			end
		end
		Queue()
	end)
	-- Fires just before combat lockdown starts: the last moment secure buttons may be hidden.
	ns.On("PLAYER_REGEN_DISABLED", function()
		if self.enabled then
			HideAll()
			M.active = {}
		end
	end)
	ns.On("PLAYER_DEAD", Queue)
	ns.On("PLAYER_UNGHOST", Queue)
	ns.On("PLAYER_MOUNT_DISPLAY_CHANGED", Queue)
	ns.Listen("FD_SPELLS_CHANGED", Queue)
	ns.Listen("FD_FORM_CHANGED", Queue)
	ns.Listen("FD_LOCK_CHANGED", Queue)
	-- Buffs expire without a combat event; re-check periodically.
	C_Timer.NewTicker(10, Queue)
end

function M:Refresh()
	if InCombatLockdown() then
		return -- secure buttons are frozen during combat; PLAYER_REGEN_ENABLED re-queues us
	end
	local cfg = ns.ModuleConfig("reminders")
	local list = (Suppressed() and not ns.db.unlocked) and {} or M.Collect(cfg)
	M.active = list

	local size, spacing = cfg.size, 8
	local count = #list
	self.anchor:SetSize(math.max(size, count * size + math.max(count - 1, 0) * spacing), size)
	for i, item in ipairs(list) do
		local frame = IconFor(i, self.anchor)
		frame:SetSize(size, size)
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (size + spacing), 0)
		local spellID = ns.KnownSpell(item.spellKey)
		frame.icon:SetTexture(spellID and ns.SpellIcon(spellID) or 134400)
		frame.label:SetText(item.label)
		frame.fdTip = item.label
		local cast = cfg.clickToCast and item.cast or nil
		frame.fdCast = cast
		frame:SetAttribute("type", cast and "spell" or nil)
		frame:SetAttribute("spell", cast)
		frame:SetAttribute("unit", cast and "player" or nil)
		frame:EnableMouse(not ns.db.unlocked)
		frame:Show()
	end
	for i = count + 1, #icons do
		icons[i]:Hide()
	end
	self.anchor:Show()
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	if InCombatLockdown() then
		-- Secure buttons can't be hidden now; do it as soon as combat ends.
		self.hideAfterCombat = true
		return
	end
	HideAll()
	self.anchor:Hide()
end
