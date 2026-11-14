# Development

Forever Druid is plain Lua 5.1 for the WoW client, with no libraries. A test suite runs the whole
addon against a model of the Forever client in standard Lua, so most work happens without starting
the game.

## Setup

You need Lua 5.4 or newer (`lua`, `luac`) and [luacheck](https://github.com/lunarmodules/luacheck).

```sh
lua tests/run.lua      # run the addon against the client model; exits non-zero on any failure
luacheck ForeverDruid && luacheck tests   # lint; separate runs, see .luacheckrc
FOREVER_ADDONS="/path/to/_forever_/Interface/AddOns" scripts/deploy.sh   # lint, test, copy into the game
scripts/package.sh     # test, then build dist/ForeverDruid-<version>.zip
```

On WSL the AddOns folder is usually under `/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns`.

CI (`.github/workflows/ci.yml`) runs syntax checks, luacheck and the tests on every push and pull
request that touches the addon. Releases are covered in [PUBLISHING.md](PUBLISHING.md).

## The rule that shapes everything: hidden values

On Forever, many values reach addon code as **secrets** (see
[How it works on Forever](forever-restrictions.md)). Addon code that compares, does arithmetic on,
concatenates, formats, indexes or boolean-tests a secret raises an error. In practice:

- **Check before you touch.** `ns.IsSecret(v)` must come before any `==`, `<`, `and`/`or`, `if v`,
  `tostring` or `..`. `ns.Readable(v)` returns `v` or nil. `ns.SafeReadable(fn, ...)` calls an API
  and returns a readable result or nil.
- **Never `x and y or z` on a value that might be secret.** `ok and alpha or 0` boolean-tests
  `alpha`. Use an explicit `if ok then ... else ... end`.
- **Widgets take secrets.** `SetValue`, `SetText`, `SetFormattedText`, `SetTexture`, `SetAlpha`,
  `SetVertexColorFromBoolean`, `SetCooldownFromExpirationTime` and
  `SetCooldownFromDurationObject` accept them. Pass hidden values straight through.
- **Thresholds go through curves.** `UnitPowerPercent` and `UnitHealthPercent` take a
  `C_CurveUtil` curve; the client evaluates it and the (still hidden) result can drive an alpha.
  Nest frames to AND two conditions.
- **When in doubt, stay quiet.** A feature that needs a readable answer checks for it and shows
  nothing if it's hidden, and counts that in its `stats` table for the probe.

The test stub's secrets raise on every operation Lua lets a table intercept. Lua can't intercept a
plain truthiness test or `==` against a non-table, so those two mistakes are caught by review, not
by the tests.

## Combat lockdown

Secure frames (click-to-cast reminders, the form bar, heal frames) and their ancestors can't be
shown, hidden, moved, re-attributed or created by addon code in combat. `PLAYER_REGEN_DISABLED`
fires just before `InCombatLockdown()` turns true, which is the last moment to hide secure buttons.
`ns.InCombat()` is true from that event on. Code that changes secure frames checks
`InCombatLockdown()`, sets a pending flag, and replays on `PLAYER_REGEN_ENABLED`. Secure anchors are
parented to `UIParent`, never to the shared root, which hides in combat situations.

## Layout of the code

The `.toc` load order is the dependency order:

| File | Role |
|---|---|
| `Locale.lua` | `ns.L`: returns the English string it is asked for |
| `Core.lua` | Namespace, event helpers (`ns.On`, `ns.OnUnit`, `ns.Listen`/`ns.Fire`, `ns.Debounce`), secret helpers, profiles and defaults, the shared root frame and visibility, movable anchors, the automatic stack, nudging and the grid, the module system |
| `Spells.lua` | The spell catalogue (`ns.SPELLS`, keyed names with fallback IDs), spellbook scan (`ns.KnownSpell`, `ns.IsCastable`, ranks, passives), player aura lookup |
| `Spec.lua` | Form detection, talent trees, unspent points, role (`ns.role`), `FD_FORM_CHANGED` / `FD_ROLE_CHANGED` |
| `Libs/` | Vendored LibStub and LibRangeCheck-3.0 (v39 from upstream main, MIT); see `NOTICE` |
| `Widgets.lua` | The shared icon widget and its styles, usable/range tints, the ready pulse, preview samples |
| `AggroData.lua` | `ns.aggro`: aggro radius estimate, Forever's detect-range auras, the pull log in `ForeverDruidProbe.aggro` and learning from it. `Modules/AggroRadius.lua` draws it on nameplates |
| `Modules/*.lua` | One file per HUD part, each registered with `ns.RegisterModule` |
| `Probe.lua` | Snapshots of what the client exposes, capability checks, CPU use |
| `Onboarding.lua` | Welcome tour, What's new (`ns.RELEASE_NOTES`), confirmation popups, windows |
| `Share.lua` | Profile export/import: serializer, base64, a data-only parser, import validation |
| `MacroList.lua` | The FD macros: names, spells needed, text and page groups |
| `Macros.lua` | Creating, updating and deleting them, and the FD Reshift button |
| `Ranks.lua` | Highest-rank action bar upgrades |
| `Leveling.lua` | Reagent restock, trainer and class-quest reminders |
| `Tooltip.lua` | Druid values on item tooltips |
| `Commands.lua` | Slash commands (`/fd ...`) and key bindings |
| `Options.lua` | The settings pages |
| `MinimapButton.lua` | Minimap button and quick settings menu |

### Modules

```lua
local M = ns.RegisterModule("mything", {})
function M:Init() end     -- once, the first time it's enabled: create the anchor, register events
function M:Enable() end   -- when switched on (and at login if enabled)
function M:Disable() end  -- when switched off
function M:Refresh() end  -- after a setting changes
```

Defaults go in `ns.defaults.modules.mything` in `Core.lua` (at least `enabled` and `scale`), a
title, note and settings page in `Options.lua`, and the file in the `.toc`. To join the HUD column,
add the key to `ns.STACK_ORDER`. Anchors come from
`ns.CreateAnchor(key, w, h, defaultPoint, label, { fade =, secure = })`.

Events from the game use `ns.On(event, fn)` and `ns.OnUnit(event, unit, fn)`. Internal messages use
`ns.Fire` / `ns.Listen`: `FD_LOGIN`, `FD_SPELLS_CHANGED`, `FD_FORM_CHANGED`, `FD_ROLE_CHANGED`,
`FD_LOCK_CHANGED`, `FD_REMINDERS_CHANGED`, `FD_MACROS_CHANGED`.

## Tests

`tests/wow_stub.lua` is a model of the Forever client built from probe data and the client's API
documentation:

- secret values that raise on use
- combat lockdown that refuses changes to secure frames
- the real event order around combat
- curves, duration objects and shapeshift forms
- auras that go secret in combat
- macros, action bars and the cursor
- spell ranks, merchants, party members and Blizzard's secure group header
- tooltips, Settings and the Menu system

`tests/run.lua` runs the suites in `tests/suites/` (`core`, `hud`, `setup`, `macros`, `aggro`), which play through scenarios with it: login, each form, combat, mounting, profiles,
imports, macros and so on. A run fails on any Lua error, blocked protected action or failed
expectation.

When you add a feature, add a scenario, and include the case where the client hides what the
feature needs. If the stub lacks an API, add it to the stub modelled on the API docs. Never make
the stub more permissive than the client.

## Probe-driven changes

Behaviour that depends on what Forever allows starts as a probe check, ships quiet-when-hidden,
and is tuned from real snapshots. When a probe result changes what the stub should do, update the
stub first, then the code.

## Style

Tabs, `local` everything, short comments that explain *why*. Player-facing text goes through
`L[...]`. Release notes in `ns.RELEASE_NOTES` describe what a player gets, not how it's built.
