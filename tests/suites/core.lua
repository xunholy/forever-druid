-- Login, forms, roles, upgrades, levelling helpers and the non-druid path.
-- Run through tests/run.lua, which provides check, section, noErrors, fresh, login and labels.

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("login: feral-specced Skyborne druid in caster form")
	login(W)
	noErrors(W, "no Lua errors on login")
	check(ns.isDruid, "detects druid")
	check(ns.profileName == "Default", "uses the Default profile")
	check(ns.tree == "feral" and ns.role == "feral", ("talent line feral, role feral (got %s/%s)"):format(tostring(ns.tree), tostring(ns.role)))
	check(ns.KnownSpell("readLeyline") == 1259705, "finds Forever's Read Leyline (1259705)")
	check(not ns.modules.manabar.bar:IsShown(), "mana bar hidden in caster form")
	check(ns.global.lastVersion == ns.VERSION, "records the version for the update notice")

	local reminders = ns.modules.reminders
	local set = labels(reminders.active)
	check(set["Mark"], "reminds about Mark of the Wild")
	check(set["Seeds 0"], "reminds about Rebirth seeds")
	check(set["Ley line"], "Skyborne: reminds to attune at a ley line")
	check(not set["Thorns"], "no Thorns reminder outside Bear Form by default")

	local markButton
	for i, item in ipairs(reminders.active) do
		if item.label == "Mark" then
			markButton = _G["ForeverDruidReminder" .. i]
		end
	end
	check(markButton and markButton:GetAttribute("type") == "spell" and markButton:GetAttribute("spell") == "Mark of the Wild",
		"Mark reminder is a click-to-cast button for Mark of the Wild")

	W.state.auras["Mark of the Wild"] = { spellId = 5232, duration = 1800, expirationTime = W.now + 1800 }
	W.state.auras["Attuned"] = { spellId = 1259691, duration = 3600, expirationTime = W.now + 3600 }
	W.state.items[17034] = 5
	W.Fire("UNIT_AURA", "player", {})
	W.Fire("BAG_UPDATE_DELAYED")
	W.Advance(1)
	check(#reminders.active == 0, "reminders clear once buffed, attuned and stocked (" .. #reminders.active .. " left)")

	section("Cat Form: mana bar and combo points")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.1)
	check(ns.form == "cat" and ns.role == "cat", "form/role = cat")
	local manabar = ns.modules.manabar
	check(manabar.bar:IsShown(), "mana bar shown in Cat Form")
	check(manabar.text:GetText() == "<secret text>", "mana text formatted by the client from secret values")
	check(manabar.marker:IsShown(), "powershift cost marker shown (cost 400 of 4000)")
	check(manabar.bar._color and #manabar.bar._color == 3, "mana bar coloured through the curve")

	W.state.power[4] = 3
	W.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	local combo = ns.modules.combopoints
	check(combo.anchor:IsShown(), "combo points shown in Cat Form")

	local cooldowns = ns.modules.cooldowns
	check(cooldowns.count == 8, "cat row: 6 cat spells + 2 Skyborne racials (got " .. tostring(cooldowns.count) .. ")")

	section("combat: auras go secret, power stays secret")
	W.state.auras["Clearcasting"] = { spellId = 16870, duration = 15, expirationTime = W.now + 15 }
	W.state.auras["Tiger's Fury"] = { spellId = 5217, duration = 6, expirationTime = W.now + 6 }
	W.Fire("UNIT_AURA", "player", {})
	W.Advance(0.2)
	local buffs = ns.modules.buffs
	local before = {}
	for _, item in ipairs(buffs.active) do
		before[item.key] = true
	end
	check(before.clearcasting and before.tigersFury, "buffs: Clearcasting and Tiger's Fury shown out of combat")

	W.state.targetExists = true
	W.state.targetHostile = true
	W.state.targetAuras = {
		{ icon = 132152, expirationTime = W.now + 9, duration = 9, applications = 0, auraInstanceID = 501 },
		{ icon = 132122, expirationTime = W.now + 12, duration = 12, applications = 0, auraInstanceID = 502 },
	}
	W.Fire("PLAYER_TARGET_CHANGED")
	W.Advance(0.2)
	local target = ns.modules.targetauras
	check(target.stats.shown == 2, "target: two of my debuffs shown (got " .. tostring(target.stats.shown) .. ")")

	-- The client fires PLAYER_REGEN_DISABLED just before lockdown starts.
	W.Fire("PLAYER_REGEN_DISABLED")
	W.state.inCombat = true
	W.state.secretAuras = true
	W.Fire("UNIT_POWER_FREQUENT", "player", "MANA")
	W.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
	W.Fire("UNIT_MAXPOWER", "player")
	W.Fire("SPELL_UPDATE_COOLDOWN")
	W.Fire("UNIT_AURA", "player", {})
	W.Fire("UNIT_AURA", "target", {})
	W.Advance(3)
	noErrors(W, "no Lua errors or blocked actions in combat")
	check(cooldowns.stats.durationCalls > 0 and cooldowns.stats.durationFailures == 0, "cooldowns drawn from duration objects")
	local during = {}
	for _, item in ipairs(buffs.active) do
		during[item.key] = item.stale and "stale" or "live"
	end
	check(during.clearcasting == "live", "Clearcasting still readable in combat (whitelisted aura)")
	check(during.tigersFury == "stale", "Tiger's Fury kept, dimmed, when the client refuses the lookup")
	check(target.stats.shown == 2, "target debuffs still drawn from secret fields in combat")
	check(#reminders.active == 0, "reminders hidden in combat")

	W.Advance(5) -- Tiger's Fury (6s) has now expired
	W.Fire("UNIT_AURA", "player", {})
	W.Advance(0.2)
	local after = {}
	for _, item in ipairs(buffs.active) do
		after[item.key] = true
	end
	check(not after.tigersFury, "stale Tiger's Fury dropped once its timer ran out")

	check(ForeverDruidProbe and #ForeverDruidProbe.snapshots >= 2, "probe auto-snapshots at login and first combat")
	local snaps = ForeverDruidProbe and ForeverDruidProbe.snapshots or {}
	local snap = { power = { mana = {} } }
	for _, each in ipairs(snaps) do
		if each.tag == "combat" then
			snap = each
		end
	end
	check(snap.tag == "combat" and snap.power.mana.value == "<secret>", "combat snapshot records mana as <secret>")
	check(snap.auraSecrecy and snap.auraSecrecy.clearcasting and snap.auraSecrecy.clearcasting.secret == false, "probe records per-aura secrecy")
	check(snap.moduleStats and snap.moduleStats.targetauras, "probe records module stats")

	W.Slash("unlock")
	check(not ns.db.unlocked, "unlock refused during combat")

	section("leave combat, Bear Form")
	W.state.inCombat = false
	W.state.secretAuras = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.state.form = 2
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(1)
	check(ns.role == "bear", "role = bear")
	check(cooldowns.count == 6, "bear row: Enrage, Barkskin, Innervate, Rebirth + 2 racials (got " .. tostring(cooldowns.count) .. ")")
	check(labels(reminders.active)["Thorns"], "Thorns reminder in Bear Form")

	section("mounting hides the HUD")
	W.state.mounted = true
	W.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	W.Advance(0.2)
	check(not ns.root:IsShown(), "root hidden while mounted")
	W.state.mounted = false
	W.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	W.Advance(0.2)
	check(ns.root:IsShown(), "root shown again after dismounting")

	section("slash commands, custom cooldowns, profiles, options panel")
	for _, cmd in ipairs({ "", "help", "status", "unlock", "lock", "reset", "toggle manabar", "toggle manabar",
		"toggle nope", "cd add all Nature's Grasp", "cd add bear Growl", "cd list", "cd remove bear Growl", "cd add moon Wrath",
		"probe", "config", "profile", "profile list" }) do
		W.Slash(cmd)
	end
	W.Advance(0.5)
	noErrors(W, "all slash commands run cleanly")
	check(ns.db.modules.manabar.enabled == true, "toggle twice leaves the mana bar on")
	check(#ns.db.modules.cooldowns.extra.all == 1, "custom cooldown stored")
	check(ns.db.unlocked == false, "lock state restored")
	check(W.ShowOptionsPanel(), "options panel registered and shown")
	noErrors(W, "options panel widgets refresh cleanly")

	W.Slash("profile use Tank")
	check(ns.global.chars[ns.charKey] == "Tank" and ns.global.profiles.Tank, "profile switch recorded for next load")
	W.Slash("profile copy Default")
	W.Slash("profile delete Default")
	check(ns.global.profiles.Default ~= nil, "the active profile can't be deleted")
	W.Slash("profile delete Tank")
	check(ns.global.profiles.Tank == nil and ns.global.chars[ns.charKey] == "Default", "deleting another profile moves its characters to Default")

	ForeverDruid_OnAddonCompartmentClick(nil, "RightButton")
	check(ns.db.unlocked == true, "addon compartment right-click unlocks")
	ForeverDruid_OnAddonCompartmentClick(nil, "RightButton")
	ForeverDruid_OnAddonCompartmentClick(nil, "LeftButton")
	noErrors(W, "addon compartment entry works")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("friendly target shows my HoTs; restoration role; missing talent API")
	W.state.trees = { { "Balance", 0 }, { "Feral Combat", 0 }, { "Restoration", 31 } }
	login(W)
	check(ns.role == "healer", "resto points -> healer role (got " .. tostring(ns.role) .. ")")
	W.state.targetExists = true
	W.state.targetHostile = false
	W.state.targetAuras = { { icon = 136081, expirationTime = W.now + 12, duration = 12, applications = 0, auraInstanceID = 9 } }
	W.Fire("PLAYER_TARGET_CHANGED")
	W.Advance(0.2)
	check(ns.modules.targetauras.stats.shown == 1, "my Rejuvenation on a friendly target is shown")
	C_Traits = nil
	W.Fire("TRAIT_CONFIG_UPDATED")
	W.Advance(0.2)
	check(ns.role == "caster", "falls back to caster role without talent data (got " .. tostring(ns.role) .. ")")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("review regressions: combat state inside PLAYER_REGEN_DISABLED, deferred hides, secret combo points")
	login(W)
	ns.db.fadeOutOfCombat = 0.3
	ns.db.modules.cooldowns.hideOutOfCombat = true
	ns.UpdateVisibility()
	ns.modules.cooldowns:Refresh()
	local manaAnchor = ns.anchors.manabar
	check(manaAnchor:GetAlpha() == 0.3, "HUD faded to 0.3 out of combat")
	check(not ns.modules.cooldowns.anchor:IsShown(), "cooldowns hidden out of combat when asked")

	-- InCombatLockdown() is still false while PLAYER_REGEN_DISABLED handlers run.
	W.Fire("PLAYER_REGEN_DISABLED")
	check(manaAnchor:GetAlpha() == 1, "HUD at full opacity as combat starts")
	check(ns.modules.cooldowns.anchor:IsShown(), "cooldowns shown as combat starts")
	W.state.inCombat = true

	W.Slash("toggle reminders")
	check(ns.modules.reminders.hideAfterCombat, "disabling reminders in combat defers the hide")
	W.state.power[4] = nil
	local realGetComboPoints = GetComboPoints
	GetComboPoints = function()
		return W.Secret()
	end
	W.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	check(ns.modules.combopoints.text:GetText() == "<secret text>", "secret combo points shown as client-formatted text")
	GetComboPoints = realGetComboPoints
	W.Advance(1)
	noErrors(W, "no errors or blocked actions")

	-- PLAYER_REGEN_ENABLED fires after lockdown has ended.
	W.state.inCombat = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(0.5)
	check(not ns.modules.reminders.anchor:IsShown(), "reminders hidden once combat ended")
	check(manaAnchor:GetAlpha() == 0.3, "HUD fades again after combat")
	noErrors(W, "no blocked actions after combat")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh()
	section("/reload in the middle of combat")
	W.state.inCombat = true
	W.state.secretAuras = true
	login(W)
	W.Advance(1)
	noErrors(W, "login under combat lockdown creates no secure frames and errors nothing")
	check(#ns.modules.reminders.active == 0, "reminders wait for combat to end")
	W.state.inCombat = false
	W.state.secretAuras = false
	W.Fire("PLAYER_REGEN_ENABLED")
	W.Advance(1)
	check(#ns.modules.reminders.active > 0, "reminders appear once combat ends")
	noErrors(W, "no blocked actions after combat")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh(function(W)
		ForeverDruidCharDB = { modules = { manabar = { width = 222 } }, unlocked = false, positions = {} }
	end)
	section("upgrade from v0.1.0 per-character settings")
	login(W)
	check(ns.db.modules.manabar.width == 222, "old per-character settings carried into the profile")
	check(ForeverDruidCharDB == nil, "legacy per-character table cleared")
	noErrors(W, "no errors")
end

---------------------------------------------------------------------------
do
	local W, ns = fresh(function(W)
		W.state.class = "WARLOCK"
		W.unknownEvents = { LEARNED_SPELL_IN_SKILL_LINE = true, PLAYER_CONTROL_LOST = true }
	end)
	section("non-druid: modules stay off, probe still works, unknown events tolerated")
	login(W)
	W.Slash("probe")
	W.Advance(6)
	noErrors(W, "no errors on a warlock")
	check(not ns.modules.manabar.initialized, "druid modules not initialised")
	check(ForeverDruidProbe and #ForeverDruidProbe.snapshots >= 1, "manual probe recorded")
end

---------------------------------------------------------------------------
do
	section("role: close talent split guesses Feral, and you can pick your caster-form role")
	local W, ns = fresh(function(W)
		W.state.trees = { { "Balance", 0 }, { "Feral Combat", 4 }, { "Restoration", 5 } }
	end)
	login(W)
	check(ns.tree == "feral" and ns.role == "feral", "4 Feral / 5 Restoration: treated as Feral (got " .. tostring(ns.role) .. ")")
	ns.db.role = "healer"
	ns.UpdateRole()
	check(ns.role == "healer", "picked Healer: caster-form role is healer")
	W.state.form = 1
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(ns.role == "cat", "Cat Form still decides its own role")
	W.state.form = 0
	W.Fire("UPDATE_SHAPESHIFT_FORM")
	W.Advance(0.5)
	check(ns.role == "healer", "back in caster form: your pick again")
	ns.db.role = "auto"
	ns.UpdateRole()
	noErrors(W, "no errors")

	local W2, ns2 = fresh(function(W)
		W.state.trees = { { "Balance", 0 }, { "Feral Combat", 2 }, { "Restoration", 11 } }
	end)
	login(W2)
	check(ns2.role == "healer", "a clear Restoration build stays a healer")
	noErrors(W2, "no errors")
end

---------------------------------------------------------------------------
do
	section("levelling helpers: restock, trainer visit, class quests; probe capability checks")
	local W, ns = fresh(function(W)
		W.state.level = 20
		table.insert(W.state.spellbook, { 21849, "Gift of the Wild" })
	end)
	login(W)
	W.Advance(5)
	-- Rebirth rank 1 needs Maple Seed; Gift of the Wild rank 1 needs Wild Berries.
	W.state.items[17034] = 1
	W.merchant = {
		{ item = 17034, name = "Maple Seed", price = 100 },
		{ item = 17035, name = "Stranglethorn Seed", price = 200 },
		{ item = 17021, name = "Wild Berries", price = 150 },
		{ item = 4540, name = "Tough Hunk of Bread", price = 25 },
	}
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	check(#W.bought == 0, "restock is off by default: nothing bought")
	ns.db.restock.enabled = true
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	local bought = {}
	for _, b in ipairs(W.bought) do
		bought[b.item] = b.count
	end
	check(bought[17034] == 4 and bought[17035] == nil, "tops up the seed for your Rebirth rank to 5 (had 1, bought " .. tostring(bought[17034]) .. ")")
	check(bought[17021] == 10, "buys 10 Wild Berries for Gift of the Wild rank 1")
	check(bought[4540] == nil, "never buys anything else")
	W.bought = {}
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	check(#W.bought == 0, "already stocked: buys nothing")
	W.state.items[17034], W.state.items[17021], W.money = 0, 0, 250
	W.bought = {}
	W.Fire("MERCHANT_SHOW")
	W.Advance(1)
	local spent = 0
	for _, b in ipairs(W.bought) do
		spent = spent + b.count
	end
	check(W.money >= 0 and spent <= 2, "only what you can afford (" .. tostring(W.money) .. " copper left)")

	-- Trainer: after an even level until you open a trainer.
	W.Fire("PLAYER_LEVEL_UP", 22)
	W.Advance(1)
	check(labels(ns.modules.reminders.active)["Trainer"], "levelling to 22 shows a trainer reminder")
	W.Fire("TRAINER_SHOW")
	W.Advance(1)
	check(not labels(ns.modules.reminders.active)["Trainer"], "opening the trainer clears it")
	W.Fire("PLAYER_LEVEL_UP", 23)
	W.Advance(1)
	check(not labels(ns.modules.reminders.active)["Trainer"], "odd levels don't")
	noErrors(W, "no errors")

	-- Class quest: level 20 without Cat Form.
	local W2, ns2 = fresh(function(W)
		W.state.level = 20
		for i = #W.state.spellbook, 1, -1 do
			if W.state.spellbook[i][2] == "Cat Form" then
				table.remove(W.state.spellbook, i)
			end
		end
	end)
	login(W2)
	W2.Advance(5)
	check(labels(ns2.modules.reminders.active)["Cat Form"], "level 20 without Cat Form: class quest reminder")
	check(not labels(ns2.modules.reminders.active)["Bear Form"], "has Bear Form: no reminder for it")
	local reminderButton
	for i, item in ipairs(ns2.modules.reminders.active) do
		if item.label == "Cat Form" then
			reminderButton = _G["ForeverDruidReminder" .. i]
		end
	end
	check(reminderButton and reminderButton:GetAttribute("type") == nil, "the quest reminder isn't a cast button")

	-- Probe: capability checks saved in combat.
	W2.state.inCombat = false
	W2.Fire("PLAYER_REGEN_DISABLED")
	W2.state.inCombat = true
	W2.Fire("UNIT_AURA", "player", { addedAuras = { { spellId = 16870 }, { spellId = W2.Secret() } } })
	local snap = ns2.TakeSnapshot("caps")
	local caps = snap.capabilities
	check(caps and caps.auraAdded.readableID == 1 and caps.auraAdded.secretID == 1 and caps.auraAdded.clearcasting == 1,
		"probe counts readable vs secret 'aura added' spell IDs in combat")
	check(caps.threat == nil or caps.threatRaw == "<secret>", "probe records whether threat is secret")
	check(caps.attackSpeed == 2.5, "probe records attack speed")
	W2.state.inCombat = false
	W2.Fire("PLAYER_REGEN_ENABLED")
	noErrors(W2, "no errors")
end
