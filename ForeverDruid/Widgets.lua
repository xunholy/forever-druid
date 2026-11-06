-- Shared look and feel: one icon widget for every row (cooldowns, buffs, target effects,
-- reminders), the icon style setting, the "ready" pulse, the usable / range tints and the sample
-- content shown while the HUD is unlocked.

local _, ns = ...

---------------------------------------------------------------------------
-- Icon style
---------------------------------------------------------------------------

-- minimal: icon cropped to its art with a thin black frame.
-- blizzard: the icon's own bevelled border, as on action bars and aura buttons.
ns.ICON_STYLES = { "minimal", "blizzard" }

local styled = setmetatable({}, { __mode = "k" }) -- every icon frame, for restyling in place

local function Theme()
	local style = ns.db and ns.db.style
	return style and style.icons or "minimal"
end

-- Fields we attach ourselves; rawget so a frame without one reads as nil.
local function Part(frame, key)
	return rawget(frame, key)
end

function ns.StyleIcon(frame)
	local minimal = Theme() ~= "blizzard"
	local border, icon, cooldown = Part(frame, "border"), Part(frame, "icon"), Part(frame, "cooldown")
	if border then
		border:SetShown(minimal)
	end
	if icon then
		if minimal then
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		else
			icon:SetTexCoord(0, 1, 0, 1)
		end
	end
	if cooldown and cooldown.SetCountdownFont then
		-- Outlined numbers stay readable over bright icon art.
		pcall(cooldown.SetCountdownFont, cooldown, "GameFontHighlightOutline")
	end
end

function ns.RestyleAll()
	for frame in pairs(styled) do
		ns.StyleIcon(frame)
	end
end

-- Adds the black frame behind an existing icon frame (used directly by the secure reminder
-- buttons, which can't come from CreateIcon because of their template).
function ns.AddIconBorder(frame, color)
	local border = frame:CreateTexture(nil, "BACKGROUND")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(unpack(color or { 0, 0, 0, 0.8 }))
	frame.border = border
	styled[frame] = true
	return border
end

-- opts.reverse: aura-style timer (fills as it runs out).
-- opts.count: add a stack-count number in the corner.
-- opts.tints: add usable / out-of-range overlays (cooldown icons).
function ns.CreateIcon(parent, size, opts)
	opts = opts or {}
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(size, size)
	ns.AddIconBorder(frame, opts.borderColor)

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	frame.icon = icon

	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	cooldown:SetAllPoints()
	cooldown:SetDrawEdge(false)
	if opts.reverse then
		cooldown:SetReverse(true)
	end
	frame.cooldown = cooldown

	if opts.count then
		local count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		count:SetPoint("BOTTOMRIGHT", -1, 1)
		frame.count = count
	end

	if opts.tints then
		-- Blue when you lack the mana/rage/energy, red when the target is out of range.
		local power = frame:CreateTexture(nil, "OVERLAY")
		power:SetAllPoints(icon)
		power:SetColorTexture(1, 1, 1, 1)
		power:SetVertexColor(0, 0, 0, 0)
		frame.powerTint = power
		local range = frame:CreateTexture(nil, "OVERLAY")
		range:SetAllPoints(icon)
		range:SetColorTexture(1, 1, 1, 1)
		range:SetVertexColor(0, 0, 0, 0)
		frame.rangeTint = range
	end

	ns.StyleIcon(frame)
	return frame
end

---------------------------------------------------------------------------
-- Usable / range tints
---------------------------------------------------------------------------

-- Colours come from the client's own booleans through SetVertexColorFromBoolean, which accepts
-- secret values, so the tints keep working in combat where the booleans can't be read.
local colors
local function Colors()
	if not colors and CreateColor then
		colors = {
			white = CreateColor(1, 1, 1, 1),
			dim = CreateColor(0.45, 0.45, 0.45, 1),
			clear = CreateColor(0, 0, 0, 0),
			blue = CreateColor(0.2, 0.35, 1, 0.45),
			red = CreateColor(1, 0.1, 0.1, 0.45),
		}
	end
	return colors
end

ns.tintStats = { calls = 0, failures = 0 }

local function Reset(frame)
	frame.icon:SetVertexColor(1, 1, 1, 1)
	if frame.powerTint then
		frame.powerTint:SetVertexColor(0, 0, 0, 0)
		frame.rangeTint:SetVertexColor(0, 0, 0, 0)
	end
end

function ns.ApplyTints(frame, spellID, usable, range)
	local c = Colors()
	if not (c and spellID and frame.icon.SetVertexColorFromBoolean) then
		return
	end
	ns.tintStats.calls = ns.tintStats.calls + 1
	local ok = pcall(function()
		if usable and C_Spell.IsSpellUsable then
			local isUsable, noPower = C_Spell.IsSpellUsable(spellID)
			frame.icon:SetVertexColorFromBoolean(isUsable, c.white, c.dim)
			frame.powerTint:SetVertexColorFromBoolean(noPower, c.blue, c.clear)
		else
			frame.icon:SetVertexColor(1, 1, 1, 1)
			frame.powerTint:SetVertexColor(0, 0, 0, 0)
		end
		-- No and/or here: "out of range" is false, and `false or nil` would turn it into "no check".
		local inRange
		if range and C_Spell.IsSpellInRange then
			inRange = C_Spell.IsSpellInRange(spellID)
		end
		-- nil means "no range to check" (self buffs, no target); a secret value is never nil.
		if ns.IsSecret(inRange) or inRange ~= nil then
			frame.rangeTint:SetVertexColorFromBoolean(inRange, c.clear, c.red)
		else
			frame.rangeTint:SetVertexColor(0, 0, 0, 0)
		end
	end)
	if not ok then
		ns.tintStats.failures = ns.tintStats.failures + 1
		pcall(Reset, frame)
	end
end

function ns.ClearTints(frame)
	if Part(frame, "powerTint") then
		pcall(Reset, frame)
	end
end

---------------------------------------------------------------------------
-- "Ready" pulse
---------------------------------------------------------------------------

function ns.Pulse(frame)
	if not frame.CreateAnimationGroup then
		return
	end
	local pulse = Part(frame, "fdPulse")
	if not pulse then
		local glow = frame:CreateTexture(nil, "OVERLAY", nil, 7)
		glow:SetPoint("CENTER")
		glow:SetSize(frame:GetWidth() * 1.8, frame:GetHeight() * 1.8)
		glow:SetTexture("Interface\\Cooldown\\star4")
		glow:SetBlendMode("ADD")
		glow:SetAlpha(0)
		pulse = frame:CreateAnimationGroup()
		local grow = pulse:CreateAnimation("Scale")
		grow:SetScaleFrom(0.4, 0.4)
		grow:SetScaleTo(1.2, 1.2)
		grow:SetDuration(0.35)
		grow:SetTarget(glow)
		local fadeIn = pulse:CreateAnimation("Alpha")
		fadeIn:SetFromAlpha(0)
		fadeIn:SetToAlpha(1)
		fadeIn:SetDuration(0.12)
		fadeIn:SetTarget(glow)
		local fadeOut = pulse:CreateAnimation("Alpha")
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(0)
		fadeOut:SetStartDelay(0.15)
		fadeOut:SetDuration(0.35)
		fadeOut:SetTarget(glow)
		frame.fdPulse, frame.fdGlow = pulse, glow
	end
	frame.fdGlow:SetSize(frame:GetWidth() * 1.8, frame:GetHeight() * 1.8)
	pulse:Stop()
	pulse:Play()
	ns.pulseCount = (ns.pulseCount or 0) + 1
end

---------------------------------------------------------------------------
-- Preview: sample content while the HUD is unlocked, so empty rows have something to arrange
---------------------------------------------------------------------------

function ns.Previewing()
	return ns.db and ns.db.unlocked and ns.db.preview ~= false or false
end

-- A readable aura-shaped table the normal drawing code accepts.
function ns.SampleAura(spellID, duration, remaining, stacks)
	return {
		spellId = spellID,
		icon = ns.SpellIcon(spellID),
		duration = duration,
		expirationTime = GetTime() + remaining,
		applications = stacks or 0,
	}
end
