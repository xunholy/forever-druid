-- luacheck config for ForeverDruid (WoW addon, Lua 5.1 runtime).
-- Lint ForeverDruid and tests in separate runs (CI and deploy.sh do): the stub defines the client API as
-- globals, and luacheck shares globals defined in one checked file with the rest, hiding undeclared API use.
std = "lua51"
max_line_length = 160
max_string_line_length = false -- player-facing sentences are allowed to run long
self = false -- methods often ignore self (module:ShouldShow etc.)
codes = true
exclude_files = { "dist/", "ForeverDruid/Libs/" } -- Libs are vendored and linted upstream

-- Globals the addon defines.
globals = {
	"ForeverDruid",
	"ForeverDruidDB", "ForeverDruidProbe", "ForeverDruidCharDB",
	"SLASH_FOREVERDRUID1", "SLASH_FOREVERDRUID2", "SlashCmdList",
	"ForeverDruid_OnAddonCompartmentClick", "ForeverDruid_OnAddonCompartmentEnter",
	"ForeverDruid_OnAddonCompartmentLeave",
	"BINDING_HEADER_FOREVERDRUID", "BINDING_NAME_FOREVERDRUID_UNLOCK", "BINDING_NAME_FOREVERDRUID_MENU",
	"BINDING_NAME_FOREVERDRUID_OPTIONS",
	"ForeverDruid_ToggleUnlock", "ForeverDruid_OpenQuickMenu", "ForeverDruid_OpenOptions",
	"StaticPopupDialogs",
	"UISpecialFrames", -- we add our windows so Esc closes them
}

-- WoW API and FrameXML the addon reads.
read_globals = {
	-- Stat conversions (item tooltips)
	"GetCombatRatingBonusForCombatRatingValue", "GetCritChanceFromStat", "GetDodgeChanceFromAttribute",
	"GetSpellCritChanceFromStat", "MANA_PER_INTELLECT", "UnitHPPerStamina", "UnitStat",
	"C_AddOns", "C_Container", "C_CurveUtil", "C_Item", "C_RestrictedActions", "C_Secrets", "C_Spell", "C_SpellBook",
	"C_SpecializationInfo", "C_ClassTalents", "C_Timer", "C_Traits", "C_UnitAuras", "C_AddOnProfiler", "C_Texture",
	"CreateFrame", "CreateColor", "UIParent", "GameTooltip", "Minimap", "MenuUtil", "Settings", "Enum",
	"GetTime", "GetRealmName", "GetBuildInfo", "GetCursorPosition", "GetMinimapShape",
	"GetShapeshiftForm", "GetShapeshiftFormInfo", "GetNumShapeshiftForms", "GetComboPoints",
	"GetSpellCooldown", "GetSpellInfo", "GetSpellTexture", "GetFramerate",
	"InCombatLockdown", "IsMounted", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
	"UnitAffectingCombat", "UnitCanAttack", "UnitClass", "UnitExists", "UnitInVehicle", "UnitIsDeadOrGhost",
	"UnitLevel", "UnitName", "UnitOnTaxi", "UnitPower", "UnitPowerMax", "UnitPowerPercent", "UnitRace",
	"UnitIsFriend", "UnitGUID",
	"ReloadUI", "PlaySound", "SOUNDKIT", "StaticPopup_Show", "StaticPopup_Hide", "ChatFrame_OpenChat",
	"WOW_PROJECT_ID", "WOW_PROJECT_CAMELOT",
	"hooksecurefunc", "issecretvalue", "securecallfunction", "wipe", "strsplit", "strtrim", "strlower", "strupper",
	"format", "tinsert", "tremove", "date", "time", "debugstack", "geterrorhandler", "seterrorhandler",
	"YES", "NO", "OKAY", "CANCEL", "ACCEPT", "Constants",
	"CreateMacro", "EditMacro", "DeleteMacro", "GetMacroIndexByName", "GetMacroInfo", "GetNumMacros", "PickupMacro", "ShowMacroFrame", "RegisterStateDriver",
	"GetActionInfo", "PlaceAction", "ClearCursor", "GetCursorInfo", "C_ActionBar",
	"GetMerchantNumItems", "GetMerchantItemID", "BuyMerchantItem", "GetMoney", "C_MerchantFrame",
	"GetMerchantItemMaxStack", "IsTradeskillTrainer",
	"UnitThreatSituation", "UnitDetailedThreatSituation", "UnitThreatPercentageOfLead", "UnitAttackSpeed",
	"IsInGroup", "UnitGroupRolesAssigned", "UnitHealthPercent",
	"TooltipDataProcessor", "ItemRefTooltip", "GetInventoryItemLink", "GetInventoryItemID", "UnitInRange", "ATTRIBUTE_NOOP",
	"C_NamePlate", "LibStub", "UnitReaction", "UnitIsPlayer", "UnitIsDead", "UnitIsUnit", "UnitClassification",
	"IsStealthed", "GetRealZoneText",
	"_G",
}

files["tests/"] = {
	std = "lua54",
	allow_defined_top = true,
	globals = { "*" }, -- the stub stands in for the whole client
	ignore = { "111", "112", "113", "121", "122", "131", "142", "143", "211", "212", "311", "431", "631" },
}
