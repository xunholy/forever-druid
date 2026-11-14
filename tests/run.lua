-- Runs ForeverDruid against the WoW Forever stub: login, every form, combat with secret values,
-- target auras, click-to-cast reminders, profiles, slash commands and the
-- options panel. Exits non-zero on any Lua error, blocked protected action or failed expectation.
--   lua tests/run.lua

package.path = "./tests/?.lua;" .. package.path

local out = print -- the stub replaces the global print to capture addon chat output
local failures = 0
local function check(cond, message)
	if cond then
		out("  ok   " .. message)
	else
		failures = failures + 1
		out("  FAIL " .. message)
	end
end

local function section(name)
	out("\n== " .. name)
end

local function noErrors(W, label)
	local detail = ""
	if #W.errors > 0 then
		detail = ": " .. W.errors[1]
	elseif #W.blocked > 0 then
		detail = ": blocked " .. W.blocked[1]
	end
	check(#W.errors == 0 and #W.blocked == 0, label .. detail)
end

local function fresh(setup)
	package.loaded.wow_stub = nil
	ForeverDruidCharDB, ForeverDruidProbe, ForeverDruidDB = nil, nil, nil
	local W = require("wow_stub")
	if setup then
		setup(W)
	end
	local ns = W.LoadAddon("ForeverDruid", "ForeverDruid")
	return W, ns
end

local function login(W)
	W.Fire("ADDON_LOADED", "ForeverDruid")
	W.Fire("PLAYER_LOGIN")
	W.Fire("PLAYER_ENTERING_WORLD", true, false)
	W.Advance(1)
end

local function labels(list)
	local set = {}
	for _, r in ipairs(list) do
		set[r.label] = true
	end
	return set
end
---------------------------------------------------------------------------
-- The suites share the helpers above through their environment. Anything else they read or set is
-- a real global, exactly as when this was one file: the addon and the stub live in _G.
local env = setmetatable({ out = out, check = check, section = section, noErrors = noErrors, fresh = fresh,
	login = login, labels = labels }, {
	__index = _G,
	__newindex = function(_, key, value)
		_G[key] = value
	end,
})
for _, name in ipairs({ "core", "hud", "setup", "macros", "aggro" }) do
	local chunk = assert(loadfile("tests/suites/" .. name .. ".lua", "t", env))
	chunk()
end

out(("\n%s (%d failure%s)"):format(failures == 0 and "PASS" or "FAIL", failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
