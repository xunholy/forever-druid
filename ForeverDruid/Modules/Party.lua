-- Party panel: one row per party member with your HoTs on them (Rejuvenation, Regrowth...) and
-- their timers, a Rebirth hint when one is dead, and an Innervate hint that fades in when a
-- healer runs low on mana.
--
-- HoTs come from C_UnitAuras.GetUnitAuras(unit, "HELPFUL|PLAYER") and go straight into widgets,
-- like the target row, so timers run even when the numbers are secret. The Innervate hint never
-- reads anyone's mana: a curve turns their mana percentage into the icon's alpha inside the
-- client (SetAlpha accepts the secret result). If the client hides a party member's auras
-- entirely, that row just shows the name; the probe counts it.

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("party", {})

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local UNITS = { "player", "party1", "party2", "party3", "party4" }
local HEALER_CLASSES = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }
local MAX_HOTS = 4
local HOT_KEYS = { "rejuvenation", "regrowth" }

M.stats = { queries = 0, failures = 0, secretEntries = 0, shown = 0, rows = 0 }
local rows = {}
local lowManaCurve

local function BuildCurve()
	if lowManaCurve or not (C_CurveUtil and C_CurveUtil.CreateCurve) then
		return lowManaCurve
	end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if ok and curve then
		local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear
		if linear and curve.SetType then
			curve:SetType(linear)
		end
		-- Fully visible under 25% mana, fading out by 40%.
		curve:AddPoint(0.0, 1)
		curve:AddPoint(0.25, 1)
		curve:AddPoint(0.40, 0)
		curve:AddPoint(1.0, 0)
		lowManaCurve = curve
	end
	return lowManaCurve
end

local function Units()
	local cfg = ns.ModuleConfig("party")
	local list = {}
	for _, unit in ipairs(UNITS) do
		if (unit ~= "player" or cfg.includeSelf) and ns.SafeReadable(UnitExists, unit) then
			list[#list + 1] = unit
		end
	end
	return list
end

-- Your HoTs on a unit (AuraData tables, fields possibly secret), capped at MAX_HOTS.
function M.HotsOn(unit)
	local out = {}
	if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
		return out
	end
	M.stats.queries = M.stats.queries + 1
	-- Ask for all of your buffs, then keep the HoTs: Mark of the Wild and Thorns would otherwise
	-- crowd them out of a short list.
	local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL|PLAYER", 40)
	if not ok or ns.IsSecret(list) or type(list) ~= "table" then
		M.stats.failures = M.stats.failures + 1
		return out
	end
	local hotNames = {}
	for _, key in ipairs(HOT_KEYS) do
		local name = ns.SpellName(key)
		if name then
			hotNames[name] = true
		end
	end
	for _, aura in ipairs(list) do
		if #out >= MAX_HOTS then
			break
		end
		if ns.IsSecret(aura) then
			M.stats.secretEntries = M.stats.secretEntries + 1
		else
			local name = aura.name
			if ns.IsSecret(name) then
				-- Can't tell what it is in combat: show it rather than hide a HoT.
				M.stats.secretEntries = M.stats.secretEntries + 1
				out[#out + 1] = aura
			elseif name and hotNames[name] then
				out[#out + 1] = aura
			end
		end
	end
	return out
end

local function AssignedRole(unit)
	local role = UnitGroupRolesAssigned and ns.SafeReadable(UnitGroupRolesAssigned, unit)
	return type(role) == "string" and role or "NONE"
end

-- Healer by assigned role; by class only when nobody in the group has a role assigned.
local function IsHealer(unit, groupHasRoles)
	if unit == "player" then
		return false -- you don't Innervate-hint yourself
	end
	local role = AssignedRole(unit)
	if role == "HEALER" then
		return true
	elseif role ~= "NONE" or groupHasRoles then
		return false
	end
	local ok, _, classFile = pcall(UnitClass, unit)
	if not ok or ns.IsSecret(classFile) or type(classFile) ~= "string" then
		return false
	end
	return HEALER_CLASSES[classFile] or false
end

local function RowFor(index)
	local row = rows[index]
	if row then
		return row
	end
	local cfg = ns.ModuleConfig("party")
	row = CreateFrame("Frame", nil, M.anchor)
	local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	name:SetPoint("LEFT", row, "LEFT", 0, 0)
	name:SetWidth(70)
	name:SetJustifyH("LEFT")
	row.name = name
	row.hots = {}
	for i = 1, MAX_HOTS do
		local icon = ns.CreateIcon(row, cfg.size, { reverse = true, count = true, borderColor = { 0.1, 0.6, 0.2, 0.9 } })
		icon:Hide()
		row.hots[i] = icon
	end
	row.rebirth = ns.CreateIcon(row, cfg.size)
	row.rebirth.icon:SetTexture(ns.SpellIcon(20484))
	row.rebirth:Hide()
	row.innervate = ns.CreateIcon(row, cfg.size)
	row.innervate.icon:SetTexture(ns.SpellIcon(29166))
	row.innervate:Hide()
	rows[index] = row
	return row
end

local NAME_WIDTH = 74

-- Width of a row's content at an icon size.
local function RowWidth(size)
	return NAME_WIDTH + MAX_HOTS * (size + 2) + 6 + size
end

-- Sizes and positions every part of a row, so the size slider applies to rows already made.
local function LayoutRow(row, size)
	row:SetSize(RowWidth(size), size)
	for i, icon in ipairs(row.hots) do
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", row, "LEFT", NAME_WIDTH + (i - 1) * (size + 2), 0)
	end
	local hintX = NAME_WIDTH + MAX_HOTS * (size + 2) + 6
	for _, hint in ipairs({ row.rebirth, row.innervate }) do
		hint:SetSize(size, size)
		hint:ClearAllPoints()
		hint:SetPoint("LEFT", row, "LEFT", hintX, 0)
	end
end

function M:ShouldShow()
	if ns.db.unlocked then
		return true
	end
	local cfg = ns.ModuleConfig("party")
	if not (IsInGroup and ns.SafeReadable(IsInGroup)) then
		return false
	end
	return not cfg.healerOnly or ns.role == "healer"
end

local function FillSample(row, i)
	row.name:SetText(({ "Tank", "Healer", "Rogue" })[i] or "Party")
	local hot = row.hots[1]
	hot.icon:SetTexture(ns.SpellIcon(774))
	hot.cooldown:SetCooldown(GetTime() - 3, 12)
	hot:Show()
	for k = 2, MAX_HOTS do
		row.hots[k]:Hide()
	end
	row.rebirth:SetShown(i == 3)
	row.innervate:SetShown(i == 2)
	row.innervate:SetAlpha(1)
end

function M:Refresh()
	local cfg = ns.ModuleConfig("party")
	local show = self:ShouldShow() and true or false
	self.anchor:SetShown(show)
	if not show then
		return
	end
	local units = ns.Previewing() and { "s1", "s2", "s3" } or Units()
	local rebirthKnown = ns.IsCastable("rebirth")
	local innervateKnown = ns.IsCastable("innervate")
	local curve = BuildCurve()
	local groupHasRoles = false
	for _, unit in ipairs(units) do
		groupHasRoles = groupHasRoles or (unit ~= "player" and AssignedRole(unit) ~= "NONE")
	end
	for i, unit in ipairs(units) do
		local row = RowFor(i)
		LayoutRow(row, cfg.size)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", self.anchor, "TOPLEFT", 0, -(i - 1) * (cfg.size + 4))
		if ns.Previewing() then
			FillSample(row, i)
		else
			row.name:SetText(UnitName(unit)) -- may be secret; the font string draws it anyway
			local hots = M.HotsOn(unit)
			for k = 1, MAX_HOTS do
				local icon, aura = row.hots[k], hots[k]
				if aura then
					local ok = pcall(function()
						icon.icon:SetTexture(aura.icon)
						icon.cooldown:SetCooldownFromExpirationTime(aura.expirationTime, aura.duration)
					end)
					icon:SetShown(ok)
				else
					icon:Hide()
				end
			end
			local dead = ns.SafeReadable(UnitIsDeadOrGhost, unit) == true
			-- You can't Rebirth yourself.
			row.rebirth:SetShown(cfg.rebirthHint and rebirthKnown and dead and unit ~= "player" or false)
			local hintInnervate = cfg.innervateHint and innervateKnown and not dead and IsHealer(unit, groupHasRoles)
				and curve and UnitPowerPercent
			if hintInnervate then
				local ok, alpha = pcall(UnitPowerPercent, unit, MANA, false, curve)
				if ok then
					row.innervate:SetAlpha(alpha) -- secret is fine: the client applies it
					row.innervate:Show()
				else
					row.innervate:Hide()
				end
			else
				row.innervate:Hide()
			end
		end
		row:Show()
	end
	for i = #units + 1, #rows do
		rows[i]:Hide()
	end
	M.stats.rows = #units
	self.anchor:SetSize(RowWidth(cfg.size), math.max(cfg.size, #units * (cfg.size + 4) - 4))
end

function M:Init()
	local cfg = ns.ModuleConfig("party")
	-- Anchored by its top edge so it grows downwards as people join instead of shifting.
	self.anchor = ns.CreateAnchor("party", RowWidth(cfg.size), cfg.size, { "TOP", "CENTER", -320, 80 }, L["Party"], { fade = true })
	local function Queue()
		if self.enabled then
			ns.Debounce("party", 0.1, function()
				if self.enabled then
					self:Refresh()
				end
			end)
		end
	end
	for _, unit in ipairs(UNITS) do
		ns.OnUnit("UNIT_AURA", unit, Queue)
	end
	ns.On("GROUP_ROSTER_UPDATE", Queue)
	ns.Listen("FD_ROLE_CHANGED", Queue)
	ns.Listen("FD_LOCK_CHANGED", Queue)
	-- Mana, deaths and expiring HoTs don't all raise events we can use; refresh twice a second.
	C_Timer.NewTicker(0.5, Queue)
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
