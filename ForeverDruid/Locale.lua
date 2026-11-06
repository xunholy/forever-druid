-- Localization. English strings are the keys themselves; other locales override them below.
-- Missing translations fall back to English automatically.

local _, ns = ...

local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L = L

local locale = GetLocale and GetLocale() or "enUS"

if locale == "deDE" then
	L["Mana bar"] = "Manaleiste"
	L["Energy tick"] = "Energietick"
	L["Combo points"] = "Kombopunkte"
	L["Cooldowns"] = "Abklingzeiten"
	L["Buffs & procs"] = "Buffs & Procs"
	L["My effects on target"] = "Meine Effekte auf dem Ziel"
	L["Reminders"] = "Erinnerungen"
end
