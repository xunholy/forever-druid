-- "Next ability": Blizzard's own rotation suggestion, shown as an icon by the HUD and as a glow on
-- the action button that holds it.
--
-- The game decides the suggestion itself with the real numbers (energy, buffs, target health),
-- which addons can't read on Forever, and hands back only a spell ID. C_AssistedCombat.IsAvailable()
-- says whether the client offers it at all; when it doesn't, nothing shows and the probe records
-- the reason. The glow is a separate frame laid over the button, never a change to the button.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("nextability", {})

local BUTTONS_PER_BAR = 12
local DEFAULT_BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton",
	"MultiBarRightButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }

M.stats = { available = nil, reason = nil, suggestions = 0, secret = 0, none = 0, glowed = 0 }

local glows = {} -- button -> overlay frame
local current -- spell ID being suggested

function M.Available()
	local api = C_AssistedCombat
	if not (api and api.IsAvailable and api.GetNextCastSpell) then
		M.stats.available, M.stats.reason = false, "missing"
		return false
	end
	local ok, available, reason = pcall(api.IsAvailable)
	if not ok or ns.IsSecret(available) then
		M.stats.available, M.stats.reason = false, ok and "secret" or "error"
		return false
	end
	M.stats.available = available and true or false
	M.stats.reason = not available and ns.Readable(reason) or nil
	return M.stats.available
end

-- The suggested spell ID, or nil.
function M.Suggestion()
	if not M.Available() then
		return nil
	end
	local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell, false)
	if not ok or spellID == nil then
		M.stats.none = M.stats.none + 1
		return nil
	end
	if ns.IsSecret(spellID) then
		M.stats.secret = M.stats.secret + 1
		return nil
	end
	M.stats.suggestions = M.stats.suggestions + 1
	return spellID
end

---------------------------------------------------------------------------
-- Action button glow
---------------------------------------------------------------------------

local function BarNames()
	local util = ActionButtonUtil and ActionButtonUtil.ActionBarButtonNames
	return type(util) == "table" and util or DEFAULT_BARS
end

-- Same spell, or another rank of it (by name).
local function Matches(actionSpell, wanted, wantedName)
	if actionSpell == wanted then
		return true
	end
	local name = wantedName and ns.SafeReadable(C_Spell.GetSpellName, actionSpell)
	return name ~= nil and name == wantedName
end

function M.ButtonsFor(spellID)
	local out = {}
	if not (spellID and GetActionInfo) then
		return out
	end
	local wantedName = ns.SafeReadable(C_Spell.GetSpellName, spellID)
	for _, prefix in ipairs(BarNames()) do
		for i = 1, BUTTONS_PER_BAR do
			local button = _G[prefix .. i]
			local slot = button and rawget(button, "action")
			if type(slot) == "number" and button:IsVisible() then
				local kind, id = GetActionInfo(slot)
				if not ns.IsSecret(kind) and kind == "spell" and not ns.IsSecret(id) and type(id) == "number"
					and Matches(id, spellID, wantedName) then
					out[#out + 1] = button
				end
			end
		end
	end
	return out
end

local function GlowFor(button)
	local glow = glows[button]
	if glow then
		return glow
	end
	-- Parented to UIParent and only anchored to the button, so the (secure) button is never
	-- touched and showing or hiding the glow is fine in combat.
	glow = CreateFrame("Frame", nil, UIParent)
	glow:SetFrameStrata("HIGH")
	glow:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
	glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
	local tex = glow:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints()
	-- The standard square button highlight (used throughout Forever's own UI), tinted gold.
	tex:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	tex:SetBlendMode("ADD")
	tex:SetVertexColor(1, 0.82, 0.2, 1)
	glow.tex = tex
	if glow.CreateAnimationGroup then
		local pulse = glow:CreateAnimationGroup()
		pulse:SetLooping("BOUNCE")
		local fade = pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.45)
		fade:SetDuration(0.5)
		glow.pulse = pulse
	end
	glow:Hide()
	glows[button] = glow
	return glow
end

local function ClearGlows(except)
	for button, glow in pairs(glows) do
		if not (except and except[button]) then
			if glow.pulse then
				glow.pulse:Stop()
			end
			glow:Hide()
		end
	end
end

function M:UpdateGlows(spellID)
	local cfg = ns.ModuleConfig("nextability")
	if not (cfg.glow and spellID) then
		ClearGlows()
		return
	end
	local keep = {}
	for _, button in ipairs(M.ButtonsFor(spellID)) do
		keep[button] = true
		local glow = GlowFor(button)
		if not glow:IsShown() then
			glow:Show()
			if glow.pulse then
				glow.pulse:Play()
			end
			M.stats.glowed = M.stats.glowed + 1
		end
	end
	ClearGlows(keep)
end

---------------------------------------------------------------------------
-- HUD icon
---------------------------------------------------------------------------

function M:ShouldShow()
	if ns.db.unlocked then
		return true
	end
	local cfg = ns.ModuleConfig("nextability")
	if cfg.combatOnly and not ns.InCombat() then
		return false
	end
	return M.Available()
end

function M:Init()
	local cfg = ns.ModuleConfig("nextability")
	self.anchor = ns.CreateAnchor("nextability", cfg.size, cfg.size, { "CENTER", "CENTER", -110, -160 }, L["Next ability"], { fade = false })
	local icon = ns.CreateIcon(self.anchor, cfg.size)
	icon:SetAllPoints()
	self.icon = icon
	local label = self.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOP", self.anchor, "BOTTOM", 0, -2)
	label:SetText(L["Next"])
	self.label = label

	local function Update()
		if self.enabled then
			local ok, err = pcall(self.Update, self)
			if not ok then
				ns.ReportError(err)
			end
		end
	end
	ns.On("ASSISTED_COMBAT_ACTION_SPELL_CAST", Update)
	ns.On("SPELL_UPDATE_COOLDOWN", Update)
	ns.On("PLAYER_TARGET_CHANGED", Update)
	ns.On("ACTIONBAR_SLOT_CHANGED", Update)
	ns.On("ACTIONBAR_PAGE_CHANGED", Update)
	ns.On("UPDATE_BONUS_ACTIONBAR", Update)
	ns.On("PLAYER_REGEN_DISABLED", Update)
	ns.On("PLAYER_REGEN_ENABLED", Update)
	ns.Listen("FD_LOCK_CHANGED", Update)
	ns.Listen("FD_FORM_CHANGED", Update)
	-- The suggestion changes with energy and procs, which raise no event we can use.
	C_Timer.NewTicker(0.15, Update)
end

function M:Update()
	local show = self:ShouldShow() and true or false
	self.anchor:SetShown(show)
	local spellID
	if ns.Previewing() then
		spellID = ns.KnownSpell("claw") or ns.KnownSpell("maul") or 5176
	elseif show then
		spellID = M.Suggestion()
	end
	current = spellID
	if spellID then
		self.icon.icon:SetTexture(ns.SpellIcon(spellID))
		self.icon.spellID = spellID
		if ns.modules.cooldowns and ns.modules.cooldowns.ApplyCooldown then
			ns.modules.cooldowns.ApplyCooldown(self.icon)
		end
		self.icon:SetAlpha(1)
	else
		self.icon:SetAlpha(0.25)
	end
	self:UpdateGlows(show and not ns.Previewing() and spellID or nil)
end

function M.Current()
	return current
end

function M:Refresh()
	local cfg = ns.ModuleConfig("nextability")
	self.anchor:SetSize(cfg.size, cfg.size)
	self:Update()
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
	ClearGlows()
end
