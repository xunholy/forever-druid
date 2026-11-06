-- Form bar: a compact row of your forms next to the HUD. Click to shift; your current form is
-- lit, each shows its mana cost (out of combat, when readable) and the global cooldown sweep.
--
-- The buttons are secure (click-to-cast), so they're built and re-labelled out of combat only;
-- the highlight and the cooldown sweep are plain drawing and update in combat too.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("formbar", {})

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local buttons = {}
local pending = false
M.stats = { builds = 0, deferred = 0 }

local function ButtonFor(index)
	local button = buttons[index]
	if button then
		return button
	end
	local cfg = ns.ModuleConfig("formbar")
	button = CreateFrame("Button", "ForeverDruidForm" .. index, M.anchor, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetSize(cfg.size, cfg.size)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	button.icon = icon
	ns.AddIconBorder(button)
	ns.StyleIcon(button)
	local lit = button:CreateTexture(nil, "OVERLAY")
	lit:SetPoint("TOPLEFT", -2, 2)
	lit:SetPoint("BOTTOMRIGHT", 2, -2)
	lit:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	lit:SetBlendMode("ADD")
	lit:SetVertexColor(1, 0.85, 0.3, 1)
	lit:SetAlpha(0)
	button.lit = lit
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints()
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)
	button.cooldown = cooldown
	local cost = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	cost:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)
	button.cost = cost
	button:SetScript("OnEnter", function(self)
		if GameTooltip and self.fdSpell then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetSpellByID(self.fdSpell)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	buttons[index] = button
	return button
end

local function ManaCost(spellID)
	local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
	if not ok or ns.IsSecret(costs) or type(costs) ~= "table" then
		return nil
	end
	for _, entry in ipairs(costs) do
		local kind, amount = ns.Readable(entry.type), ns.Readable(entry.cost)
		if kind == MANA and type(amount) == "number" and amount > 0 then
			return amount
		end
	end
end

-- Rebuilds the buttons from your stance bar. Out of combat only (secure buttons).
function M:Build()
	if InCombatLockdown() then
		pending = true
		M.stats.deferred = M.stats.deferred + 1
		return false
	end
	pending = false
	local cfg = ns.ModuleConfig("formbar")
	local forms = ns.ShapeshiftForms()
	local count = 0
	for _, f in ipairs(forms) do
		if f.spellID then
			count = count + 1
			local button = ButtonFor(count)
			local name = ns.SafeReadable(C_Spell.GetSpellName, f.spellID)
			button:SetSize(cfg.size, cfg.size)
			button:ClearAllPoints()
			button:SetPoint("LEFT", self.anchor, "LEFT", (count - 1) * (cfg.size + 4), 0)
			button.icon:SetTexture(ns.SpellIcon(f.spellID))
			button.fdSpell, button.fdIndex = f.spellID, f.index
			button:SetAttribute("type", name and "spell" or nil)
			button:SetAttribute("spell", name)
			local cost = cfg.showCost and ManaCost(f.spellID)
			button.cost:SetText(cost and tostring(cost) or "")
			button:EnableMouse(not ns.db.unlocked)
			button:Show()
		end
	end
	for i = count + 1, #buttons do
		buttons[i]:SetAttribute("type", nil)
		buttons[i]:Hide()
	end
	self.anchor:SetSize(math.max(cfg.size, count * (cfg.size + 4) - 4), cfg.size)
	self.count = count
	M.stats.builds = M.stats.builds + 1
	self:UpdateState()
	return true
end

-- Highlight and cooldown: drawing only, fine in combat.
function M:UpdateState()
	local active = GetShapeshiftForm and ns.SafeReadable(GetShapeshiftForm)
	for i = 1, self.count or 0 do
		local button = buttons[i]
		button.lit:SetAlpha((active and button.fdIndex == active) and 1 or 0)
		if C_Spell.GetSpellCooldownDuration and button.cooldown.SetCooldownFromDurationObject then
			pcall(function()
				local duration = C_Spell.GetSpellCooldownDuration(button.fdSpell, false)
				if duration then
					button.cooldown:SetCooldownFromDurationObject(duration, true)
				else
					button.cooldown:Clear()
				end
			end)
		end
	end
end

function M:Init()
	local cfg = ns.ModuleConfig("formbar")
	self.anchor = ns.CreateAnchor("formbar", cfg.size, cfg.size, { "CENTER", "CENTER", -150, -230 }, L["Form bar"], { secure = true })
	local function Rebuild()
		if self.enabled then
			self:Build()
		end
	end
	local function State()
		if self.enabled then
			self:UpdateState()
		end
	end
	ns.Listen("FD_SPELLS_CHANGED", Rebuild)
	ns.Listen("FD_LOCK_CHANGED", Rebuild)
	ns.On("UPDATE_SHAPESHIFT_FORMS", Rebuild)
	ns.On("UPDATE_SHAPESHIFT_FORM", State)
	ns.On("SPELL_UPDATE_COOLDOWN", State)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if not pending then
			return
		end
		if self.enabled then
			self.anchor:Show()
			self:Build()
		else
			pending = false
			self.anchor:Hide()
		end
	end)
end

function M:Refresh()
	self:Build()
end

function M:Enable()
	if InCombatLockdown() then
		pending = true
		return
	end
	self.anchor:Show()
	self:Build()
end

function M:Disable()
	if InCombatLockdown() then
		pending = true
		return
	end
	self.anchor:Hide()
end
