# Tests

`lua tests/run.lua` loads the addon through its TOC into `wow_stub.lua`, a stand-in for the
WoW Forever client built from what the probe recorded on a live client: secret power values,
auras and cooldowns that turn secret in combat, combat lockdown that blocks secure frames, and
the order `PLAYER_REGEN_DISABLED` / `InCombatLockdown()` actually happen in.

Each scenario prints `ok` or `FAIL`; the run exits non-zero on any failure, Lua error or blocked
protected action. Lint with `luacheck .` (config in `.luacheckrc`).
