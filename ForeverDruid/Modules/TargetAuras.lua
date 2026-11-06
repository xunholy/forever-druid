-- "My effects on target": your DoTs on an enemy (Rake, Rip, Moonfire, Insect Swarm, Faerie Fire,
-- Demoralizing Roar, Lacerate…) or your HoTs on a friend (Rejuvenation, Regrowth…), big and next
-- to the HUD.
--
-- The list comes from C_UnitAuras.GetUnitAuras with a PLAYER filter, the same call Blizzard's
-- nameplates use. Every field is passed straight to a widget (icon texture, expiration time,
-- stack text), so the timers keep running in combat even when the values are secret.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("targetauras", {})

local icons = {}
M.stats = { queries = 0, failures = 0, shown = 0, secretEntries = 0 }

local HOSTILE_FILTER = "HARMFUL|PLAYER"
local FRIENDLY_FILTER = "HELPFUL|PLAYER"

-- Which filters to query for the current target. Unknown reaction → both.
function M.Filters()
	local exists = ns.SafeReadable(UnitExists, "target")
	if not exists then
		return {}
	end
	local canAttack = ns.SafeReadable(UnitCanAttack, "player", "target")
	if canAttack == true then
		return { HOSTILE_FILTER }
	elseif canAttack == false then
		return { FRIENDLY_FILTER }
	end
	return { HOSTILE_FILTER, FRIENDLY_FILTER }
end

-- Returns a list of AuraData tables (contents may be secret), capped at `max`.
function M.Collect(max)
	local out = {}
	if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
		return out
	end
	for _, filter in ipairs(M.Filters()) do
		M.stats.queries = M.stats.queries + 1
		local ok, list = pcall(C_UnitAuras.GetUnitAuras, "target", filter, max)
		if not ok or ns.IsSecret(list) or type(list) ~= "table" then
			M.stats.failures = M.stats.failures + 1
		else
			for _, aura in ipairs(list) do
				if #out >= max then
					return out
				end
				if ns.IsSecret(aura) then
					M.stats.secretEntries = M.stats.secretEntries + 1
				else
					out[#out + 1] = aura
				end
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Missing debuffs: what your role should keep on an enemy, shown dimmed when it isn't there.
-- Only when every effect on the target can be identified; one hidden name and we say nothing.
---------------------------------------------------------------------------

-- Counted with the module's other stats so the probe saves them.
M.stats.missingChecks, M.stats.missingUnknown, M.stats.missingWarnings = 0, 0, 0

local function FaerieKey()
	if (ns.form == "cat" or ns.form == "bear") and ns.IsCastable("faerieFireFeral") then
		return "faerieFireFeral"
	end
	return ns.IsCastable("faerieFire") and "faerieFire" or nil
end

-- Spell keys your current role wants on an enemy target.
function M.WantedDebuffs(role)
	local wanted = {}
	local faerie = FaerieKey()
	if role == "cat" or role == "feral" then
		wanted[#wanted + 1] = faerie
	elseif role == "bear" then
		wanted[#wanted + 1] = ns.IsCastable("demoralizingRoar") and "demoralizingRoar" or nil
		wanted[#wanted + 1] = faerie
	elseif role == "balance" then
		wanted[#wanted + 1] = faerie
		wanted[#wanted + 1] = ns.IsCastable("moonfire") and "moonfire" or nil
		wanted[#wanted + 1] = ns.IsCastable("insectSwarm") and "insectSwarm" or nil
	end
	return wanted
end

-- Keys from WantedDebuffs not found among `auras` (the target's debuffs from anyone), or nil when
-- any debuff's name is hidden, since then we can't tell.
function M.MissingDebuffs(auras, role)
	M.stats.missingChecks = M.stats.missingChecks + 1
	local present = {}
	for _, aura in ipairs(auras) do
		local name = not ns.IsSecret(aura) and type(aura) == "table" and aura.name
		if not name or ns.IsSecret(name) then
			M.stats.missingUnknown = M.stats.missingUnknown + 1
			return nil
		end
		present[name] = true
	end
	local missing = {}
	local faerieNames = { ns.SpellName("faerieFire"), ns.SpellName("faerieFireFeral") }
	-- A warrior's Demoralizing Shout does Demoralizing Roar's job.
	local shout = C_Spell and C_Spell.GetSpellName and ns.SafeReadable(C_Spell.GetSpellName, 1160)
	for _, key in ipairs(M.WantedDebuffs(role)) do
		local found = present[ns.SpellName(key)]
		if key == "demoralizingRoar" and type(shout) == "string" and present[shout] then
			found = true
		end
		if key == "faerieFire" or key == "faerieFireFeral" then
			-- Either kind of Faerie Fire does the same job.
			found = (faerieNames[1] and present[faerieNames[1]]) or (faerieNames[2] and present[faerieNames[2]])
		end
		if not found then
			missing[#missing + 1] = key
		end
	end
	return missing
end

local function AllDebuffs()
	if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
		return nil
	end
	local ok, list = pcall(C_UnitAuras.GetUnitAuras, "target", "HARMFUL", 40)
	if not ok or ns.IsSecret(list) or type(list) ~= "table" then
		return nil
	end
	return list
end

local missingIcons = {}

---------------------------------------------------------------------------
-- "Let it bleed": one of your bleeds or DoTs is ticking on an enemy that's nearly dead, so you
-- can move on to the next one. The health check happens inside the client: a curve turns the
-- target's hidden health percentage into the cue's visibility, so ForeverDruid never sees the
-- number and never has to guess it.
---------------------------------------------------------------------------

M.stats.bleedChecks, M.stats.bleedCues, M.stats.bleedUnknownNames = 0, 0, 0

local DOT_SPELLS = { "rake", "rip", "moonfire", "insectSwarm" }
local bleedCurve, bleedCurveFor

local function BleedCurve(threshold)
	if bleedCurve and bleedCurveFor == threshold then
		return bleedCurve
	end
	if not (C_CurveUtil and C_CurveUtil.CreateCurve) then
		return nil
	end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if not ok or not curve then
		return nil
	end
	local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear
	if linear and curve.SetType then
		curve:SetType(linear)
	end
	-- Fully shown at or under the threshold, gone a few percent above it.
	curve:AddPoint(0, 1)
	curve:AddPoint(threshold, 1)
	curve:AddPoint(math.min(threshold + 0.03, 1), 0)
	curve:AddPoint(1, 0)
	bleedCurve, bleedCurveFor = curve, threshold
	return curve
end

-- Is one of your damaging bleeds or DoTs among your effects on the target? When the client hides
-- the names, Cat Form and Balance count any effect of yours (nearly all of theirs are damaging).
function M.HasMyDot(auras)
	local names = {}
	for _, key in ipairs(DOT_SPELLS) do
		local name = ns.SpellName(key)
		if name then
			names[name] = true
		end
	end
	local pounce = ns.SpellName("pounceBleed")
	if pounce then
		names[pounce] = true
	end
	for _, aura in ipairs(auras) do
		local name = not ns.IsSecret(aura) and type(aura) == "table" and aura.name
		if not name or ns.IsSecret(name) then
			M.stats.bleedUnknownNames = M.stats.bleedUnknownNames + 1
			if ns.form == "cat" or ns.role == "balance" then
				return true
			end
		elseif names[name] then
			return true
		end
	end
	return false
end

local function StackText(aura)
	-- Prefer the client's formatter (handles secret counts) when the instance ID is usable.
	local id = aura.auraInstanceID
	if not ns.IsSecret(id) and id and C_UnitAuras.GetAuraApplicationDisplayCount then
		local ok, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "target", id, 2)
		if ok then
			return text
		end
	end
	local applications = aura.applications
	if ns.IsSecret(applications) then
		return ""
	end
	return (applications and applications > 1) and tostring(applications) or ""
end

local function IconFor(index, parent, size)
	local frame = icons[index]
	if not frame then
		frame = ns.CreateIcon(parent, size, { reverse = true, count = true, borderColor = { 0.6, 0.1, 0.1, 0.9 } })
		icons[index] = frame
	end
	frame:SetSize(size, size)
	return frame
end

-- Shown while unlocked: Rake, Rip and Moonfire with timers, plus a 3-stack.
function M.SampleList()
	return {
		ns.SampleAura(1822, 9, 6),
		ns.SampleAura(1079, 12, 10),
		ns.SampleAura(8921, 12, 3, 3),
	}
end

local function ApplyAura(frame, aura, friendly)
	frame.icon:SetTexture(aura.icon)
	local ok = pcall(frame.cooldown.SetCooldownFromExpirationTime, frame.cooldown, aura.expirationTime, aura.duration)
	if not ok then
		frame.cooldown:Clear()
	end
	frame.count:SetText(StackText(aura))
	if friendly then
		frame.border:SetColorTexture(0.1, 0.6, 0.2, 0.9)
	else
		frame.border:SetColorTexture(0.6, 0.1, 0.1, 0.9)
	end
end

function M:Init()
	local cfg = ns.ModuleConfig("targetauras")
	self.anchor = ns.CreateAnchor("targetauras", cfg.size, cfg.size, { "CENTER", "CENTER", 0, -140 }, L["My effects on target"], { fade = true })

	local function Queue()
		if self.enabled then
			ns.Debounce("targetauras", 0.05, function()
				if self.enabled then
					self:Refresh()
				end
			end)
		end
	end
	ns.OnUnit("UNIT_AURA", "target", Queue)
	-- Health moves faster than auras: just re-apply the cue's visibility.
	ns.OnUnit("UNIT_HEALTH", "target", function()
		if self.enabled then
			self:UpdateBleedCue()
		end
	end)

	local cue = CreateFrame("Frame", nil, self.anchor)
	cue:SetSize(160, 20)
	cue:SetPoint("BOTTOM", self.anchor, "TOP", 0, 4)
	local cueIcon = cue:CreateTexture(nil, "ARTWORK")
	cueIcon:SetSize(18, 18)
	cueIcon:SetPoint("LEFT", cue, "LEFT", 0, 0)
	cueIcon:SetTexture(ns.SpellIcon(1079))
	cueIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local cueText = cue:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	cueText:SetPoint("LEFT", cueIcon, "RIGHT", 4, 0)
	cueText:SetTextColor(1, 0.35, 0.25)
	cueText:SetText(L["Let it bleed - next target"])
	cue:Hide()
	self.cue = cue
	ns.On("PLAYER_TARGET_CHANGED", Queue)
	ns.Listen("FD_LOCK_CHANGED", Queue)
	-- Auras can drop without an event reaching us (target out of range); re-check now and then.
	C_Timer.NewTicker(1, Queue)
end

function M:Refresh()
	local cfg = ns.ModuleConfig("targetauras")
	local previewing = ns.Previewing()
	local list = previewing and M.SampleList() or M.Collect(cfg.max)
	local friendly = not previewing and ns.SafeReadable(UnitCanAttack, "player", "target") == false
	local size, spacing = cfg.size, cfg.spacing
	local count = #list
	self.anchor:SetSize(math.max(size, count * size + math.max(count - 1, 0) * spacing), size)
	local shown = 0
	for i, aura in ipairs(list) do
		local frame = IconFor(i, self.anchor, size)
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (size + spacing), 0)
		local ok = pcall(ApplyAura, frame, aura, friendly)
		frame:SetShown(ok)
		if ok then
			shown = shown + 1
		end
	end
	for i = count + 1, #icons do
		icons[i]:Hide()
	end
	M.stats.shown = shown

	-- Missing debuffs after your own, on enemies in combat.
	local missing = {}
	if previewing then
		missing = { "faerieFire" }
	elseif cfg.warnMissing and ns.InCombat() and #M.WantedDebuffs(ns.role) > 0
		and ns.SafeReadable(UnitCanAttack, "player", "target") == true then
		local debuffs = AllDebuffs()
		missing = debuffs and M.MissingDebuffs(debuffs, ns.role) or {}
	end
	for i, key in ipairs(missing) do
		local frame = missingIcons[i]
		if not frame then
			frame = ns.CreateIcon(self.anchor, size, { borderColor = { 0.9, 0.1, 0.1, 1 } })
			missingIcons[i] = frame
		end
		frame:SetSize(size, size)
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", self.anchor, "LEFT", (count + i - 1) * (size + spacing) + 6, 0)
		local spellID = ns.KnownSpell(key) or (ns.SPELLS[key] and ns.SPELLS[key][2])
		frame.icon:SetTexture(spellID and ns.SpellIcon(spellID) or 134400)
		frame.icon:SetDesaturated(true)
		frame:SetAlpha(0.85)
		frame:Show()
	end
	if #missing > 0 and not previewing then
		M.stats.missingWarnings = M.stats.missingWarnings + 1
	end
	for i = #missing + 1, #missingIcons do
		missingIcons[i]:Hide()
	end
	self.hasMyDot = not previewing and #list > 0 and M.HasMyDot(list) or false
	self:UpdateBleedCue()

	local total = count + #missing
	self.anchor:SetSize(math.max(size, total * size + math.max(total - 1, 0) * spacing + (#missing > 0 and 6 or 0)), size)
	self.anchor:Show()
end

function M:UpdateBleedCue()
	local cfg = ns.ModuleConfig("targetauras")
	local cue = self.cue
	if ns.Previewing() then
		cue:SetAlpha(1)
		cue:Show()
		return
	end
	if not (cfg.letItBleed and self.hasMyDot and UnitHealthPercent)
		or ns.SafeReadable(UnitCanAttack, "player", "target") ~= true then
		cue:Hide()
		return
	end
	local curve = BleedCurve(cfg.bleedThreshold or 0.2)
	if not curve then
		cue:Hide()
		return
	end
	M.stats.bleedChecks = M.stats.bleedChecks + 1
	local ok, alpha = pcall(UnitHealthPercent, "target", false, curve)
	if ok then
		cue:SetAlpha(alpha) -- secret is fine: the client applies it
		cue:Show()
		M.stats.bleedCues = M.stats.bleedCues + 1
	else
		cue:Hide()
	end
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
