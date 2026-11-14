-- Slash commands: /fd and everything after it. The settings panel is Options.lua.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function Status()
	ns.Print(("v%s - %s %s, %s %s, %s %s, %s %s"):format(ns.VERSION,
		L["form"], tostring(ns.form), L["talents"], tostring(ns.tree or L["none"]),
		L["role"], tostring(ns.role), L["profile"], tostring(ns.profileName)))
	if not ns.isDruid then
		ns.Print(L["Not a druid: modules are off. /fd probe still works."])
		return
	end
	local cpu = ns.CpuSummary and ns.CpuSummary()
	if cpu then
		ns.Print("  " .. cpu)
	end
	for _, key in ipairs(ns.moduleOrder) do
		ns.Print(("  %s: %s"):format(key, ns.db.modules[key].enabled and L["on"] or L["off"]))
	end
end

local function Help()
	local function Line(text)
		ns.Print("  " .. text)
	end
	ns.Print(L["commands:"] .. " |cffaaaaaa(" .. L["/fd <part> opens that part's settings, e.g. /fd heal"] .. ")|r")
	ns.Print("|cffffd100" .. L["Everyday"] .. "|r")
	Line("/fd config - " .. L["all settings"] .. "   /fd style - " .. L["choose how you play"])
	Line("/fd unlock | lock - " .. L["move the HUD"] .. "   /fd reset - " .. L["default positions"])
	Line("/fd status - " .. L["what's on and how it's doing"])
	ns.Print("|cffffd100" .. L["Layout"] .. "|r")
	Line("/fd stack on | off   /fd grid   /fd minimap")
	Line("/fd toggle <part> - " .. table.concat(ns.moduleOrder, ", "))
	ns.Print("|cffffd100" .. L["Spells"] .. "|r")
	Line("/fd macros [on | off | sync | restore]")
	Line("/fd ranks [on | off | now | keep <spell> | unkeep <spell>]")
	Line("/fd cd add|remove <role|all> <spell>   /fd cd list")
	ns.Print("|cffffd100" .. L["Profiles and help"] .. "|r")
	Line("/fd profile [list | use | copy | reset | delete | export | import]")
	Line("/fd pulls [reset] - " .. L["what the aggro radius has learned from your pulls"])
	Line("/fd tour   /fd whatsnew   /fd probe")
end

-- Words that open a part's settings page: the part's key or a friendlier alias.
local PAGE_ALIASES = {
	heal = "healframes", heals = "healframes", healing = "healframes", frames = "healframes", click = "healframes",
	hots = "party", hot = "party", tracker = "party",
	mana = "manabar", energy = "powerbar", rage = "powerbar", power = "powerbar",
	combo = "combopoints", cp = "combopoints",
	shift = "powershift", powershift = "powershift", pips = "powershift",
	cooldown = "cooldowns", cds = "cooldowns", buff = "buffs", procs = "buffs",
	target = "targetauras", dots = "targetauras", bleed = "targetauras", debuffs = "targetauras",
	alert = "alerts", aggro = "alerts",
	radius = "aggroradius", aggroradius = "aggroradius", nameplates = "aggroradius",
	remind = "reminders", reminder = "reminders", forms = "formbar", fsr = "fsr", regen = "fsr",
}

local KNOWN_COMMANDS = { "config", "options", "unlock", "lock", "reset", "status", "probe", "profile", "toggle", "cd",
	"stack", "grid", "minimap", "macros", "ranks", "tour", "whatsnew", "style", "help", "pulls" }

-- Edit distance where swapping two neighbouring letters ("rnaks") counts as one typo.
local function Distance(a, b)
	local la, lb = #a, #b
	local rows = { [0] = {} }
	for j = 0, lb do
		rows[0][j] = j
	end
	for i = 1, la do
		rows[i] = { [0] = i }
		for j = 1, lb do
			local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
			local d = math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a:sub(i, i) == b:sub(j - 1, j - 1) and a:sub(i - 1, i - 1) == b:sub(j, j) then
				d = math.min(d, rows[i - 2][j - 2] + 1)
			end
			rows[i][j] = d
		end
	end
	return rows[la][lb]
end

-- The closest known command or part name, if it's a near miss.
function ns.SuggestCommand(word)
	local best, bestDistance
	local candidates = {}
	for _, c in ipairs(KNOWN_COMMANDS) do
		candidates[#candidates + 1] = c
	end
	for alias in pairs(PAGE_ALIASES) do
		candidates[#candidates + 1] = alias
	end
	for _, key in ipairs(ns.moduleOrder) do
		candidates[#candidates + 1] = key
	end
	for _, c in ipairs(candidates) do
		local d = Distance(word, c)
		if not bestDistance or d < bestDistance or (d == bestDistance and c < best) then
			best, bestDistance = c, d
		end
	end
	if best and bestDistance <= (#word >= 5 and 2 or 1) then
		return best
	end
end

function ns.PageForWord(word)
	if ns.modules[word] then
		return word
	end
	return PAGE_ALIASES[word] or (word == "macro" and "macros") or nil
end

local function ProfileCommand(rest)
	local action, name = strsplit(" ", rest or "", 2)
	action = strlower(action or "")
	name = name and strtrim(name) or nil
	if action == "" or action == "list" then
		ns.Print(L["profile"] .. ": " .. ns.profileName .. "  (" .. table.concat(ns.ProfileNames(), ", ") .. ")")
	elseif action == "use" and name and name ~= "" then
		ns.UseProfile(name)
		ns.Print(L["switched to profile"] .. " " .. name .. " - /reload " .. L["to apply"])
	elseif action == "copy" and name and name ~= "" then
		if ns.CopyProfileFrom(name) then
			ns.Print(L["copied"] .. " " .. name .. " - /reload " .. L["to apply"])
		else
			ns.Print(L["no profile named"] .. " " .. name)
		end
	elseif action == "export" then
		ns.ShowShareWindow("export")
	elseif action == "import" then
		ns.ShowShareWindow("import")
	elseif action == "reset" then
		ns.ResetProfile()
		ns.Print(L["profile reset"] .. " - /reload " .. L["to apply"])
	elseif action == "delete" and name and name ~= "" then
		if ns.DeleteProfile(name) then
			ns.Print(L["deleted"] .. " " .. name)
		else
			ns.Print(L["can't delete the active profile or a missing one"])
		end
	else
		Help()
	end
end

local function CooldownCommand(rest)
	local action, role, name = strsplit(" ", rest or "", 3)
	action = strlower(action or "")
	role = role and strlower(role) or nil
	if action ~= "add" and action ~= "remove" and action ~= "list" then
		Help()
		return
	end
	ns.Print(ns.modules.cooldowns.EditExtra(action, role, name and strtrim(name)))
	if ns.modules.cooldowns.enabled then
		ns.modules.cooldowns:Refresh()
	end
end

-- Key Bindings > AddOns > ForeverDruid (Bindings.xml calls these).
BINDING_HEADER_FOREVERDRUID = ns.DISPLAY_NAME
BINDING_NAME_FOREVERDRUID_UNLOCK = L["Unlock / lock the HUD"]
BINDING_NAME_FOREVERDRUID_MENU = L["Quick settings menu"]
BINDING_NAME_FOREVERDRUID_OPTIONS = L["All settings"]

function ForeverDruid_ToggleUnlock()
	if ns.db and ns.isDruid and ns.SetUnlocked(not ns.db.unlocked) then
		ns.Print(ns.db.unlocked and L["unlocked: drag any green box to move the whole HUD, shift-drag one to give it its own spot, then /fd lock"] or L["locked"])
	end
end

function ForeverDruid_OpenQuickMenu()
	if ns.db and ns.isDruid and ns.OpenQuickMenu then
		ns.OpenQuickMenu()
	end
end

function ForeverDruid_OpenOptions()
	ns.OpenOptions()
end

SLASH_FOREVERDRUID1 = "/fd"
SLASH_FOREVERDRUID2 = "/foreverdruid"
SlashCmdList.FOREVERDRUID = function(input)
	local command, rest = strsplit(" ", strtrim(input or ""), 2)
	command = strlower(command or "")
	if command == "unlock" then
		if ns.SetUnlocked(true) then
			ns.Print(L["unlocked: drag any green box to move the whole HUD, shift-drag one to give it its own spot, then /fd lock"])
		end
	elseif command == "lock" then
		if ns.SetUnlocked(false) then
			ns.Print(L["locked"])
		end
	elseif command == "reset" then
		if ns.ResetPositions() then
			ns.Print(L["positions reset"])
		end
	elseif command == "stack" then
		local value = rest and strlower(strtrim(rest)) or ""
		local enabled
		if value == "on" then
			enabled = true
		elseif value == "off" then
			enabled = false
		else
			enabled = not ns.db.layout.stack
		end
		ns.SetStackEnabled(enabled)
		ns.Print(L["automatic stack"] .. " " .. (ns.db.layout.stack and L["on"] or L["off"]))
	elseif command == "macros" or command == "macro" then
		if not ns.isDruid then
			ns.Print(L["Not a druid: modules are off. /fd probe still works."])
			return
		end
		local action = rest and strlower(strtrim(rest)) or ""
		if action == "on" or action == "off" then
			ns.macros.SetManaged(action == "on")
		elseif action == "sync" or action == "update" then
			local _, result = ns.macros.Sync()
			ns.macros.Report(result)
		elseif action == "restore" then
			ns.Confirm(L["Overwrite the FD macros you edited with Forever Druid's version?"], function()
				ns.Print(L["restored"] .. " " .. ns.macros.Restore())
			end)
		else
			ns.Print(L["macros"] .. ": " .. (ns.db.macros.manage and L["on"] or L["off"]) .. "  (/fd macros on | off | sync | restore)")
			for _, def in ipairs(ns.macros.LIST) do
				ns.Print(("  %s - %s"):format(def.name, (ns.MacroStatusText(def.key))))
			end
		end
	elseif command == "ranks" or command == "rank" then
		if not ns.isDruid then
			ns.Print(L["Not a druid: modules are off. /fd probe still works."])
			return
		end
		local action, spell = strsplit(" ", rest or "", 2)
		action = strlower(action or "")
		spell = spell and strtrim(spell) or nil
		if action == "on" or action == "off" then
			ns.db.ranks.auto = action == "on"
			ns.Print(L["highest-rank action bars"] .. " " .. (ns.db.ranks.auto and L["on"] or L["off"]))
		elseif action == "keep" and spell and spell ~= "" then
			ns.ranks.SetKept(spell, true)
			ns.Print(spell .. ": " .. L["left at the rank you put on your bars"])
		elseif action == "unkeep" and spell and spell ~= "" then
			ns.ranks.SetKept(spell, false)
			ns.Print(spell .. ": " .. L["kept at the highest rank again"])
		elseif action == "now" or action == "update" then
			local done, deferred = ns.ranks.Upgrade()
			if deferred then
				ns.Print(L["will update your action bars once you're out of combat and not dragging anything"])
			elseif done == 0 then
				ns.Print(L["every spell on your bars is already the highest rank"])
			end
		else
			local kept = ns.ranks.KeptList()
			ns.Print(L["highest-rank action bars"] .. ": " .. (ns.db.ranks.auto and L["on"] or L["off"])
				.. (#kept > 0 and ("  (" .. L["kept"] .. ": " .. table.concat(kept, ", ") .. ")") or ""))
			ns.Print("  /fd ranks on | off | now | keep <spell> | unkeep <spell>")
		end
	elseif command == "grid" then
		ns.db.grid = not ns.db.grid
		ns.UpdateGrid()
		ns.Print(L["alignment grid"] .. " " .. (ns.db.grid and L["on"] or L["off"]) .. (ns.db.unlocked and "" or (" - " .. L["shows while unlocked"])))
	elseif command == "tour" then
		ns.ShowTour()
	elseif command == "whatsnew" or command == "news" then
		ns.ShowWhatsNew()
	elseif command == "minimap" then
		if not ns.isDruid then
			ns.Print(L["Not a druid: modules are off. /fd probe still works."])
			return
		end
		if not ns.SetMinimapButtonShown then
			-- The client reads an addon's file list only at startup.
			ns.Print(L["restart the game (not just /reload) to load the minimap button"])
			return
		end
		ns.SetMinimapButtonShown(ns.db.minimap.hide)
		ns.Print(L["minimap button"] .. " " .. (ns.db.minimap.hide and L["hidden"] or L["shown"]))
	elseif command == "toggle" then
		local key = rest and strlower(strtrim(rest))
		local cfg = key and ns.db.modules[key]
		if not cfg then
			ns.Print(L["unknown module"])
			return
		end
		ns.SetModuleEnabled(key, not cfg.enabled)
		ns.Print(("%s %s"):format(key, ns.db.modules[key].enabled and L["on"] or L["off"]))
	elseif command == "cd" then
		CooldownCommand(rest)
	elseif command == "profile" then
		ProfileCommand(rest)
	elseif command == "status" then
		Status()
	elseif command == "probe" then
		ns.PrintSnapshot(ns.TakeSnapshot("manual"))
	elseif command == "pulls" then
		if rest and strlower(strtrim(rest)) == "reset" then
			ns.aggro.Forget()
			ns.Print(L["pull log and learned aggro radii cleared"])
		else
			for _, line in ipairs(ns.aggro.Summary()) do
				ns.Print(line)
			end
		end
	elseif command == "config" or command == "options" then
		ns.OpenOptions()
	elseif command == "style" or command == "playstyle" then
		ns.ShowPlaystyle()
	elseif command == "" or command == "help" then
		Help()
	elseif ns.PageForWord(command) then
		ns.OpenModuleSettings(ns.PageForWord(command))
	else
		local guess = ns.SuggestCommand(command)
		if guess then
			ns.Print(L["unknown command"] .. " \"" .. command .. "\" - " .. L["did you mean"] .. " /fd " .. guess .. "?")
		else
			Help()
		end
	end
end
