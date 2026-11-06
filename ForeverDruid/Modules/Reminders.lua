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

---------------------------------------------------------------------------
-- Dismissing. Information-only reminders (trainer, class quests, talent points) go away with any
-- click; reminders that cast something keep left-click for casting and go away with a right-click.
---------------------------------------------------------------------------

local SNOOZE_SECONDS = 30 * 60
local snoozed = {} -- id -> GetTime() until which it stays hidden (this session)

local function Dismissed()
	ns.global.reminderDismissed = ns.global.reminderDismissed or {}
	local mine = ns.global.reminderDismissed[ns.charKey]
	if not mine then
		mine = {}
		ns.global.reminderDismissed[ns.charKey] = mine
	end
	return mine
end

local function Level()
	return tonumber(ns.SafeReadable(UnitLevel, "player")) or 0
end

-- How each kind of reminder is dismissed, and when it comes back.
function M.Dismiss(item)
	local id = item and item.id
	if not id then
		return
	end
	if id == "trainer" then
		if ns.leveling and ns.leveling.ClearTrainer then
			ns.leveling.ClearTrainer() -- as if you'd visited; back at the next even level
		end
	elseif id == "bearQuest" or id == "catQuest" then
		Dismissed()[id] = Level() -- back at your next level if you still don't have the form
	elseif id == "talents" then
		Dismissed().talents = item.count -- back when the number of unspent points changes
	else
		snoozed[id] = GetTime() + SNOOZE_SECONDS
	end
end

function M.IsDismissed(item)
	local id = item.id
	if not id then
		return false
	end
	if id == "bearQuest" or id == "catQuest" then
		local at = Dismissed()[id]
		return at ~= nil and Level() <= at
	elseif id == "talents" then
		return Dismissed().talents == item.count
	end
	local untilTime = snoozed[id]
	return untilTime ~= nil and GetTime() < untilTime
end

function M.Undismiss()
	wipe(snoozed)
	if ns.global and ns.global.reminderDismissed then
		ns.global.reminderDismissed[ns.charKey] = nil
	end
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
		list[#list + 1] = { id = spellKey, spellKey = spellKey, label = label, cast = castKey and ns.SpellName(castKey) or nil }
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
	if cfg.talents then
		local unspent = ns.UnspentTalentPoints and ns.UnspentTalentPoints()
		if unspent and unspent > 0 then
			list[#list + 1] = { id = "talents", count = unspent, label = L["Talents"] .. " " .. unspent,
				sampleIcon = "Interface\\Icons\\INV_Misc_Book_11",
				tip = (L["%d unspent talent points: press N to open your talents."]):format(unspent) }
		end
	end
	-- Trainer visit and class quests (Leveling.lua): information only, nothing to cast.
	if ns.leveling then
		for _, item in ipairs(ns.leveling.Reminders(cfg)) do
			list[#list + 1] = item
		end
	end
	-- Leave out anything you've dismissed.
	local shown = {}
	for _, item in ipairs(list) do
		if not M.IsDismissed(item) then
			shown[#shown + 1] = item
		end
	end
	return shown
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
		frame.icon = tex
		ns.AddIconBorder(frame)
		ns.StyleIcon(frame)
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOP", frame, "BOTTOM", 0, -2)
		frame.label = label
		frame:SetScript("OnEnter", function(self)
			if GameTooltip and self.fdTip then
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(self.fdTip)
				if self.fdCast then
					GameTooltip:AddLine(L["Click to cast"] .. " " .. self.fdCast, 1, 1, 1)
					GameTooltip:AddLine(L["Right-click to hide it for 30 minutes"], 0.7, 0.7, 0.7)
				elseif self.fdItem and self.fdItem.id == "trainer" then
					GameTooltip:AddLine(L["Click once you've trained, or to dismiss"], 0.7, 0.7, 0.7)
				elseif self.fdItem and self.fdItem.id then
					GameTooltip:AddLine(L["Click to dismiss"], 0.7, 0.7, 0.7)
				end
				GameTooltip:Show()
			end
		end)
		-- After the secure click (which casts, if anything): dismiss on release. Right-click is
		-- set to do nothing secure-side, so it never casts.
		frame:SetScript("PostClick", function(self, button, down)
			if down or not self.fdItem or ns.db.unlocked then
				return
			end
			if button == "RightButton" or not self.fdCast then
				M.Dismiss(self.fdItem)
				if GameTooltip then
					GameTooltip:Hide()
				end
				if not InCombatLockdown() then
					M:Refresh()
				end
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
	ns.Listen("FD_REMINDERS_CHANGED", Queue)
	ns.On("TRAIT_CONFIG_UPDATED", Queue)
	ns.On("PLAYER_LEVEL_UP", Queue)
	-- Buffs expire without a combat event; re-check periodically.
	C_Timer.NewTicker(10, Queue)
end

function M:Refresh()
	if InCombatLockdown() then
		return -- secure buttons are frozen during combat; PLAYER_REGEN_ENABLED re-queues us
	end
	local cfg = ns.ModuleConfig("reminders")
	local list = (Suppressed() and not ns.db.unlocked) and {} or M.Collect(cfg)
	if #list == 0 and ns.Previewing() then
		-- Nothing to remind about: show samples (not clickable) so the row can be placed.
		list = {
			{ spellKey = "markOfTheWild", label = L["Mark"], sampleIcon = 136078 },
			{ spellKey = "thorns", label = L["Thorns"], sampleIcon = 136104 },
		}
	end
	M.active = list

	local size, spacing = cfg.size, 8
	local count = #list
	self.anchor:SetSize(math.max(size, count * size + math.max(count - 1, 0) * spacing), size)
	for i, item in ipairs(list) do
		local frame = IconFor(i, self.anchor)
		frame:SetSize(size, size)
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (size + spacing), 0)
		local spellID = item.spellKey and ns.KnownSpell(item.spellKey)
		frame.icon:SetTexture(item.sampleIcon or (spellID and ns.SpellIcon(spellID)) or 134400)
		frame.label:SetText(item.label)
		frame.fdTip = item.tip or item.label
		local cast = cfg.clickToCast and item.cast or nil
		frame.fdCast = cast
		frame:SetAttribute("type", cast and "spell" or nil)
		frame:SetAttribute("spell", cast)
		frame:SetAttribute("unit", cast and "player" or nil)
		frame:SetAttribute("type2", ATTRIBUTE_NOOP or "") -- right-click never casts: it dismisses
		frame.fdItem = item.id and item or nil -- preview samples have no id: nothing to dismiss
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
