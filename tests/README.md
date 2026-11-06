# Tests

`lua tests/run.lua` loads the addon through its `.toc` into `wow_stub.lua`, a model of the WoW Forever
client, and plays through scenarios: login, every form, combat with hidden values, mounting,
profiles and imports, macros, action bar ranks, party and heal frames, and more. Each check prints
`ok` or `FAIL`. The run exits non-zero on any failure, Lua error or blocked protected action.

The stub is built from probe data and the client's API documentation: secret values that raise on
use, combat lockdown that refuses secure-frame changes, the real `PLAYER_REGEN_DISABLED` /
`InCombatLockdown()` order, curves, duration objects, the secure group header and more. See
[docs/development.md](../docs/development.md#tests) for how to extend it.
