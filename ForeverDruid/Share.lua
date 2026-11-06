-- Profile sharing: turn a profile into a text string anyone can paste back in.
--
-- The string is "!FD1!" followed by base64 of a small typed format (tables, strings, numbers,
-- booleans). Import uses a hand-written parser, never loadstring, so a pasted string can only
-- ever produce data: no functions, no code, bounded size and depth.

local _, ns = ...
local L = ns.L

local PREFIX = "!FD1!"
local MAX_LENGTH = 60000
local MAX_DEPTH = 12

---------------------------------------------------------------------------
-- Serialize
---------------------------------------------------------------------------

local function SortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		local kind = type(k)
		if kind == "string" or kind == "number" then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then
			return ta < tb
		end
		return a < b
	end)
	return keys
end

local function Encode(value, out, depth)
	local kind = type(value)
	if kind == "table" then
		if depth > MAX_DEPTH then
			error("profile nested too deeply")
		end
		out[#out + 1] = "T"
		for _, k in ipairs(SortedKeys(value)) do
			local v = value[k]
			local vk = type(v)
			if vk == "table" or vk == "string" or vk == "number" or vk == "boolean" then
				Encode(k, out, depth + 1)
				Encode(v, out, depth + 1)
			end
		end
		out[#out + 1] = "E"
	elseif kind == "string" then
		out[#out + 1] = "S" .. #value .. ":" .. value
	elseif kind == "number" then
		out[#out + 1] = "N" .. tostring(value) .. ";"
	elseif kind == "boolean" then
		out[#out + 1] = value and "B1" or "B0"
	end
end

function ns.Serialize(value)
	local out = {}
	Encode(value, out, 0)
	return table.concat(out)
end

---------------------------------------------------------------------------
-- Deserialize (data only)
---------------------------------------------------------------------------

function ns.Deserialize(text)
	local pos = 1
	local function Fail(why)
		error({ fdParse = why }, 0)
	end
	local Read
	Read = function(depth)
		if depth > MAX_DEPTH then
			Fail("too deep")
		end
		local tag = text:sub(pos, pos)
		pos = pos + 1
		if tag == "T" then
			local t = {}
			while true do
				if pos > #text then
					Fail("unterminated table")
				end
				if text:sub(pos, pos) == "E" then
					pos = pos + 1
					return t
				end
				local k = Read(depth + 1)
				local kk = type(k)
				if kk ~= "string" and kk ~= "number" then
					Fail("bad key")
				end
				t[k] = Read(depth + 1)
			end
		elseif tag == "S" then
			local colon = text:find(":", pos, true)
			local digits = colon and text:sub(pos, colon - 1)
			local len = digits and digits:match("^%d+$") and tonumber(digits)
			if not len or colon + len > #text then
				Fail("bad string")
			end
			local s = text:sub(colon + 1, colon + len)
			pos = colon + len + 1
			return s
		elseif tag == "N" then
			local semi = text:find(";", pos, true)
			local n = semi and tonumber(text:sub(pos, semi - 1))
			if not n or n ~= n or n == math.huge or n == -math.huge then
				Fail("bad number")
			end
			pos = semi + 1
			return n
		elseif tag == "B" then
			local b = text:sub(pos, pos)
			pos = pos + 1
			if b == "1" then
				return true
			elseif b == "0" then
				return false
			end
			Fail("bad boolean")
		end
		Fail("unexpected data")
	end
	local ok, result = pcall(Read, 0)
	if not ok then
		return nil, type(result) == "table" and result.fdParse or tostring(result)
	end
	if pos <= #text then
		return nil, "trailing data"
	end
	return result
end

---------------------------------------------------------------------------
-- Base64 (pure arithmetic: WoW's Lua 5.1 has no bit operators)
---------------------------------------------------------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for i = 1, #ALPHABET do
	DECODE[ALPHABET:sub(i, i)] = i - 1
end

function ns.Base64Encode(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64
		out[#out + 1] = ALPHABET:sub(c1 + 1, c1 + 1) .. ALPHABET:sub(c2 + 1, c2 + 1)
			.. (b and ALPHABET:sub(c3 + 1, c3 + 1) or "=") .. (c and ALPHABET:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

function ns.Base64Decode(text)
	text = text:gsub("%s", "")
	if #text % 4 ~= 0 then
		return nil
	end
	local out = {}
	for i = 1, #text, 4 do
		local chunk = text:sub(i, i + 3)
		local n, pad = 0, 0
		for j = 1, 4 do
			local ch = chunk:sub(j, j)
			local v
			if ch == "=" then
				pad = pad + 1
				v = 0
			else
				v = DECODE[ch]
				if not v or pad > 0 then
					return nil
				end
			end
			n = n * 64 + v
		end
		local a, b, c = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
		out[#out + 1] = string.char(a)
		if pad < 2 then
			out[#out + 1] = string.char(b)
		end
		if pad < 1 then
			out[#out + 1] = string.char(c)
		end
	end
	return table.concat(out)
end

---------------------------------------------------------------------------
-- Export / import
---------------------------------------------------------------------------

function ns.ExportProfile(name)
	local profile = ns.global.profiles[name or ns.profileName]
	if not profile then
		return nil
	end
	local text = PREFIX .. ns.Base64Encode(ns.Serialize(profile))
	if #text > MAX_LENGTH then
		return nil -- too big for the importer to accept
	end
	return text
end

-- Returns the decoded profile table, or nil and a reason.
function ns.DecodeProfile(text)
	text = strtrim(text or "")
	if #text > MAX_LENGTH then
		return nil, L["that text is too long to be a ForeverDruid profile"]
	end
	if text:sub(1, #PREFIX) ~= PREFIX then
		return nil, L["that isn't a ForeverDruid profile string"]
	end
	local raw = ns.Base64Decode(text:sub(#PREFIX + 1))
	if not raw then
		return nil, L["the profile string is damaged (copy all of it)"]
	end
	local profile, why = ns.Deserialize(raw)
	if type(profile) ~= "table" then
		return nil, L["the profile string is damaged (copy all of it)"] .. (why and (" - " .. why) or "")
	end
	return profile
end

---------------------------------------------------------------------------
-- Validation: an imported profile is rebuilt from the defaults, so only known settings of the
-- right type survive, numbers stay inside the ranges the settings allow, and nothing in it can
-- break the addon at login.
---------------------------------------------------------------------------

local RANGES = {
	scale = { 0.5, 2 }, fadeOutOfCombat = { 0, 1 },
	["layout.gap"] = { 0, 20 }, ["minimap.angle"] = { 0, 360 },
	["modules.*.scale"] = { 0.5, 2 }, ["modules.*.spacing"] = { 0, 20 }, ["modules.*.size"] = { 6, 64 },
	["modules.manabar.width"] = { 80, 400 }, ["modules.manabar.height"] = { 4, 30 },
	["modules.energytick.width"] = { 80, 400 }, ["modules.energytick.height"] = { 2, 20 },
	["modules.targetauras.max"] = { 1, 16 }, ["modules.reminders.reagentThreshold"] = { 0, 20 },
}
local CHOICES = {
	["style.icons"] = "ICON_STYLES",
}
local ROLES = { all = true, cat = true, bear = true, balance = true, healer = true, feral = true, caster = true }
local ANCHOR_KEYS = { stack = true, reminders = true }

local function Finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function Range(path)
	local generic = path:gsub("^modules%.[^.]+%.", "modules.*.")
	return RANGES[path] or RANGES[generic]
end

local function Clean(value, default, path)
	if type(default) == "table" then
		if type(value) ~= "table" then
			return nil
		end
		local out = {}
		for key, d in pairs(default) do
			local v = Clean(value[key], d, path == "" and key or (path .. "." .. key))
			if v ~= nil then
				out[key] = v
			end
		end
		return out
	end
	if type(value) ~= type(default) then
		return nil
	end
	if type(value) == "number" then
		if not Finite(value) then
			return nil
		end
		local range = Range(path)
		if range then
			value = math.max(range[1], math.min(range[2], value))
		end
	elseif type(value) == "string" then
		local list = CHOICES[path] and ns[CHOICES[path]]
		if path == "modules.manabar.text" then
			list = ns.modules.manabar and ns.modules.manabar.TEXT_MODES
		end
		if list then
			local allowed = false
			for _, choice in ipairs(list) do
				allowed = allowed or choice == value
			end
			if not allowed then
				return nil
			end
		elseif #value > 200 then
			return nil
		end
	end
	return value
end

function ns.SanitizeProfile(raw)
	local profile = Clean(raw, ns.defaults, "") or {}
	profile.unlocked = false -- never arrive with the HUD unlocked

	-- Free-form parts the defaults can't describe.
	profile.positions = {}
	for _, key in ipairs(ns.STACK_ORDER) do
		ANCHOR_KEYS[key] = true
	end
	for key, p in pairs(type(raw.positions) == "table" and raw.positions or {}) do
		if ANCHOR_KEYS[key] and type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
			and #p[1] < 20 and #p[2] < 20 and Finite(p[3]) and Finite(p[4]) then
			profile.positions[key] = { p[1], p[2], math.max(-4000, math.min(4000, p[3])), math.max(-4000, math.min(4000, p[4])) }
		end
	end
	profile.layout = profile.layout or {}
	profile.layout.detached = {}
	local detached = type(raw.layout) == "table" and type(raw.layout.detached) == "table" and raw.layout.detached or {}
	for key, value in pairs(detached) do
		if ns.IsStackable(key) and value == true then
			profile.layout.detached[key] = true
		end
	end
	profile.modules = profile.modules or {}
	profile.modules.cooldowns = profile.modules.cooldowns or {}
	local extra = {}
	local rawModules = type(raw.modules) == "table" and raw.modules or {}
	local rawExtra = type(rawModules.cooldowns) == "table" and rawModules.cooldowns.extra
	for role, names in pairs(type(rawExtra) == "table" and rawExtra or {}) do
		if ROLES[role] and type(names) == "table" then
			local list = {}
			for _, name in ipairs(names) do
				if type(name) == "string" and #name > 0 and #name <= 60 and #list < 50 then
					list[#list + 1] = name
				end
			end
			extra[role] = list
		end
	end
	profile.modules.cooldowns.extra = extra
	profile.macros = profile.macros or {}
	profile.macros.enabled = {}
	local rawMacros = type(raw.macros) == "table" and type(raw.macros.enabled) == "table" and raw.macros.enabled or {}
	for key, value in pairs(rawMacros) do
		if ns.macros and ns.macros.BY_KEY[key] and type(value) == "boolean" then
			profile.macros.enabled[key] = value
		end
	end
	return profile
end

-- Stores the profile under a free name ("Imported", "Imported 2", ...) and returns that name.
function ns.ImportProfile(text, wanted)
	local profile, why = ns.DecodeProfile(text)
	if not profile then
		return nil, why
	end
	profile = ns.SanitizeProfile(profile)
	local base = (wanted and wanted ~= "") and wanted or L["Imported"]
	local name, n = base, 1
	while ns.global.profiles[name] do
		n = n + 1
		name = base .. " " .. n
	end
	ns.global.profiles[name] = profile
	return name
end

local window
function ns.ShowShareWindow(mode)
	if not window then
		window = ns.Window("ForeverDruidShare", L["Share a profile"], 500, 300)
		local scroll = CreateFrame("ScrollFrame", "ForeverDruidShareScroll", window, "InputScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 18, -70)
		scroll:SetPoint("BOTTOMRIGHT", -18, 50)
		local edit = rawget(scroll, "EditBox")
		edit:SetWidth(440)
		edit:SetFontObject("ChatFontNormal")
		edit:SetAutoFocus(false)
		local charCount = rawget(scroll, "CharCount")
		if charCount then
			charCount:Hide()
		end
		window.edit = edit
		window.action = ns.WindowButton(window, L["Import"], 140, function()
			local name, why = ns.ImportProfile(edit:GetText())
			if not name then
				ns.Print(why)
				return
			end
			window:Hide()
			ns.Print(L["imported as profile"] .. " " .. name)
			ns.Confirm(L["Switch to the imported profile now? This reloads your interface."], function()
				ns.UseProfile(name)
				ReloadUI()
			end)
		end)
		window.action:SetPoint("BOTTOMRIGHT", -16, 14)
	end
	window.mode = mode
	window:Show() -- before focusing: a hidden edit box can't take focus
	if mode == "export" then
		window.body:SetText(L["Copy this text (Ctrl+C) and paste it into ForeverDruid's import box on another character or account."])
		window.edit:SetText(ns.ExportProfile() or "")
		window.edit:SetFocus()
		window.edit:HighlightText()
		window.action:Hide()
	else
		window.body:SetText(L["Paste a ForeverDruid profile string (Ctrl+V), then click Import. It's added as a new profile; your current one isn't changed."])
		window.edit:SetText("")
		window.edit:SetFocus()
		window.action:Show()
	end
	return window
end
