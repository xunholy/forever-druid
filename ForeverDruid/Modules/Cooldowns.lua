-- Role-aware cooldown row. Shows only spells the player knows, laid out for the current role
-- (cat, bear, balance, healer, feral-in-caster, caster), plus Skyborne racials and any spells the
-- player adds with /fd cd add. Cooldowns are drawn from duration objects, which the client renders
-- even when the underlying numbers are secret in combat (probe: 0 failures on 1.60.1.70790).

local _, ns = ...
local L = ns.L

local M = ns.RegisterModule("cooldowns", {})

M.LAYOUTS = {
	cat = { "tigersFury", "shiftingPower", "faerieFireFeral", "dash", "prowl", "feralCharge", "barkskin", "innervate", "rebirth" },
	bear = {
		"enrage", "frenziedRegeneration", "bash", "feralCharge", "primalBite", "faerieFireFeral",
		"challengingRoar", "growl", "barkskin", "innervate", "rebirth",
	},
	balance = { "naturesSwiftness", "starfall", "forceOfNature", "hurricane", "naturesGrasp", "barkskin", "innervate", "rebirth" },
	healer = { "naturesSwiftness", "swiftmend", "tranquility", "naturesGrasp", "barkskin", "innervate", "rebirth" },
	feral = { "naturesGrasp", "barkskin", "innervate", "rebirth" },
	caster = { "naturesGrasp", "barkskin", "innervate", "rebirth" },
}
M.RACIALS = { "readLeyline", "walkOnAir" }
M.ROLES = { "cat", "bear", "balance", "healer", "feral", "caster" }

local buttons = {}
M.buttons = buttons
M.stats = { durationCalls = 0, durationFailures = 0, legacyCalls = 0 }

local function ShowTooltip(button)
	if button.spellID and GameTooltip then
		GameTooltip:SetOwner(button, "ANCHOR_TOP")
		GameTooltip:SetSpellByID(button.spellID)
		GameTooltip:Show()
	end
end

local function HideTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function CreateButton(parent, size)
	local button = ns.CreateIcon(parent, size, { tints = true })
	-- A cooldown that runs out on its own flashes the icon (Clear() doesn't count: see ApplyCooldown).
	button.cooldown:SetScript("OnCooldownDone", function()
		if button.fdClearing or not button.spellID or not button:IsVisible() then
			return
		end
		if ns.ModuleConfig("cooldowns").pulse then
			ns.Pulse(button)
		end
	end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", HideTooltip)
	return button
end

local function ClearCooldown(button)
	button.fdClearing = true
	button.cooldown:Clear()
	button.fdClearing = nil
end

-- Applies the spell's cooldown to the button's Cooldown frame without reading the numbers.
function M.ApplyCooldown(button)
	local spellID = button.spellID
	local cooldown = button.cooldown
	if C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
		M.stats.durationCalls = M.stats.durationCalls + 1
		local ok, err = pcall(function()
			local duration = C_Spell.GetSpellCooldownDuration(spellID, true) -- ignore the GCD
			if duration then
				cooldown:SetCooldownFromDurationObject(duration, true)
			else
				ClearCooldown(button)
			end
		end)
		if ok then
			return
		end
		M.stats.durationFailures = M.stats.durationFailures + 1
		M.stats.lastError = tostring(err)
	end
	-- Fallback: classic start/duration, only usable while the values are readable.
	M.stats.legacyCalls = M.stats.legacyCalls + 1
	local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
	if ns.IsSecret(info) or type(info) ~= "table" then
		return
	end
	local start, length = ns.Readable(info.startTime), ns.Readable(info.duration)
	if start and length and length > 1.5 then
		cooldown:SetCooldown(start, length)
	elseif start and length then
		ClearCooldown(button)
	end
end

function M:Init()
	local cfg = ns.ModuleConfig("cooldowns")
	self.anchor = ns.CreateAnchor("cooldowns", cfg.size, cfg.size, { "CENTER", "CENTER", 0, -228 }, L["Cooldowns"], { fade = true })

	local function Update()
		if self.enabled then
			self:UpdateCooldowns()
		end
	end
	ns.On("SPELL_UPDATE_COOLDOWN", Update)
	ns.On("SPELL_UPDATE_CHARGES", Update)
	C_Timer.NewTicker(0.25, function()
		if self.enabled and self.anchor:IsVisible() then
			self:UpdateTints()
		end
	end)

	local function Rebuild()
		if self.enabled then
			self:Refresh()
		end
	end
	ns.Listen("FD_ROLE_CHANGED", Rebuild)
	ns.Listen("FD_SPELLS_CHANGED", Rebuild)
	ns.Listen("FD_LOCK_CHANGED", Rebuild)
	ns.On("PLAYER_REGEN_DISABLED", Rebuild)
	ns.On("PLAYER_REGEN_ENABLED", Rebuild)
end

-- User-added spell names for a role (plus the "all" list).
local function ExtraNames(role)
	local extra = ns.ModuleConfig("cooldowns").extra
	local names = {}
	for _, list in ipairs({ extra.all or {}, extra[role] or {} }) do
		for _, name in ipairs(list) do
			names[#names + 1] = name
		end
	end
	return names
end

-- Spell IDs to show for a role, in layout order, skipping unknown spells and duplicates.
function M.SpellsForRole(role)
	local cfg = ns.ModuleConfig("cooldowns")
	local spells, seen = {}, {}
	local function Add(spellID)
		if spellID and not seen[spellID] then
			seen[spellID] = true
			spells[#spells + 1] = spellID
		end
	end
	for _, key in ipairs(M.LAYOUTS[role] or M.LAYOUTS.caster) do
		Add(ns.KnownSpell(key))
	end
	for _, name in ipairs(ExtraNames(role)) do
		Add(ns.KnownSpellByName(name))
	end
	if cfg.racials then
		for _, key in ipairs(M.RACIALS) do
			Add(ns.KnownSpell(key))
		end
	end
	return spells
end

-- /fd cd add|remove|list support. Returns a message for the chat frame.
function M.EditExtra(action, role, name)
	local extra = ns.ModuleConfig("cooldowns").extra
	if action == "list" then
		local parts = {}
		for listRole, names in pairs(extra) do
			if #names > 0 then
				parts[#parts + 1] = listRole .. ": " .. table.concat(names, ", ")
			end
		end
		return #parts > 0 and table.concat(parts, "; ") or L["no extra cooldowns added"]
	end
	if role ~= "all" and not M.LAYOUTS[role] then
		return L["role must be all, cat, bear, balance, healer, feral or caster"]
	end
	if not name or name == "" then
		return L["give a spell name, e.g. /fd cd add all Nature's Grasp"]
	end
	extra[role] = extra[role] or {}
	local list = extra[role]
	for i, existing in ipairs(list) do
		if strlower(existing) == strlower(name) then
			if action == "remove" then
				table.remove(list, i)
				return L["removed"] .. " " .. existing
			end
			return existing .. " " .. L["is already tracked"]
		end
	end
	if action == "remove" then
		return name .. " " .. L["is not in the list"]
	end
	list[#list + 1] = name
	local known = ns.KnownSpellByName(name)
	return L["added"] .. " " .. name .. (known and "" or (" " .. L["(not in your spellbook yet)"]))
end

function M:Layout()
	local cfg = ns.ModuleConfig("cooldowns")
	local spells = M.SpellsForRole(ns.role)
	local size, spacing = cfg.size, cfg.spacing
	local count = #spells
	local width = math.max(size, count * size + math.max(count - 1, 0) * spacing)
	self.anchor:SetSize(width, size)

	for i, spellID in ipairs(spells) do
		local button = buttons[i]
		if not button then
			button = CreateButton(self.anchor, size)
			buttons[i] = button
		end
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("LEFT", self.anchor, "LEFT", (i - 1) * (size + spacing), 0)
		button.spellID = spellID
		button.icon:SetTexture(ns.SpellIcon(spellID))
		button.cooldown:SetHideCountdownNumbers(not cfg.showNumbers)
		button:EnableMouse(cfg.tooltips and not ns.db.unlocked)
		button:Show()
	end
	for i = count + 1, #buttons do
		buttons[i].spellID = nil
		buttons[i]:Hide()
	end
	self.count = count
end

function M:UpdateCooldowns()
	local previewing = ns.Previewing()
	for i, button in ipairs(buttons) do
		if button.spellID and button:IsShown() then
			if previewing and i <= 2 then
				-- Sample sweeps while unlocked, so the countdown text and spacing can be judged.
				button.cooldown:SetCooldown(GetTime() - 3 * i, 12 * i)
			else
				M.ApplyCooldown(button)
			end
		end
	end
	self:UpdateTints()
end

-- Dim when unusable, blue without the power, red out of range. Polled: range has no event.
function M:UpdateTints()
	local cfg = ns.ModuleConfig("cooldowns")
	local tint = (cfg.usableTint or cfg.rangeTint) and not ns.Previewing()
	for _, button in ipairs(buttons) do
		if button.spellID and button:IsShown() then
			if tint then
				ns.ApplyTints(button, button.spellID, cfg.usableTint, cfg.rangeTint)
			else
				ns.ClearTints(button)
			end
		end
	end
end

function M:ShouldShow()
	local cfg = ns.ModuleConfig("cooldowns")
	if ns.db.unlocked then
		return true
	end
	if cfg.hideOutOfCombat and not ns.InCombat() then
		return false
	end
	return true
end

function M:Refresh()
	self:Layout()
	if self:ShouldShow() then
		self.anchor:Show()
		self:UpdateCooldowns()
	else
		self.anchor:Hide()
	end
end

function M:Enable()
	self:Refresh()
end

function M:Disable()
	self.anchor:Hide()
end
