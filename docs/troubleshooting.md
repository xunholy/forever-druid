# Troubleshooting

## I updated and part of the HUD is missing, or BugSack is full of errors

Restart the game rather than using `/reload`. The game reads each addon's file list only when it
starts, so after an update that adds files, a `/reload` loads the new code without the new files.
Updates that only change existing files are fine with `/reload`.

## Nothing shows at all

- Check Forever Druid is ticked in the AddOns list at character select, and "Load out of date
  AddOns" isn't needed (it's built for interface 16001).
- Forever Druid only switches its HUD on for druids. On other classes, `/fd probe` still works.
- The HUD hides while you're mounted, dead, on a taxi or in a vehicle. Mounted hiding can be turned
  off under "Hide while mounted".
- Type `/fd status` to see which parts are on.

## A row is empty or missing

| Row | Usual reason |
|---|---|
| Combo points | Only in Cat Form unless you untick "Only in Cat Form". |
| Mana bar | Only in Cat and Bear Form unless "Show in every form" is on. |
| Shift pips / Powershift | Cat and Bear Form only. The cue also needs the Furor talent and only shows in combat. |
| Buffs & procs | Buffs gained mid-fight appear when the fight ends (Forever hides buffs from addons in combat). |
| HoT tracker | Only in a group, and optionally only when your role is healer. |

## Proc alerts, aggro warnings or missing debuffs never appear

These need information Forever may hide in combat, and they stay silent rather than guess. Take a
probe snapshot after a fight (`/fd probe`, then `/reload`) and share it: it records how often
each check got a readable answer.

## Macros aren't being created

- Turn macro management on: `/fd macros on`.
- Macros are only made for spells you know, and only out of combat. `/fd macros` lists each one's
  state, for example "needs Rejuvenation".
- Character macro slots are limited to 30. If they're full, Forever Druid says so; delete one in
  `/macro`.
- If you edited an FD macro, Forever Druid leaves it alone. "Restore edited macros" puts its version
  back.

## My action bars aren't switching to new ranks

They switch out of combat, and wait while you're holding something on the cursor. `/fd ranks now`
runs it immediately and says if it's waiting. Spells you've kept downranked (`/fd ranks`) are left
alone. Buttons from other action bar addons are included as long as they use the game's action
slots.

## Click-to-heal frames don't respond to a click

Clicks are set up out of combat. If you changed a click mid-fight, it applies when the fight ends.
Spells you haven't learned are skipped. "Target them" only works on left and right click.

## Something errors

Install [BugSack](https://www.curseforge.com/wow/addons/bugsack) to capture errors, then report
them (below).

## Reporting a bug

Open an issue with:

1. What you did and what you expected to see.
2. `/fd status` output.
3. Two files from `World of Warcraft/_forever_/WTF/Account/<ACCOUNT>/SavedVariables/`, after a
   `/reload` or logout:
   - `ForeverDruid.lua`
   - `!BugGrabber.lua`, if you use BugSack

### What's in those files

- **`ForeverDruid.lua`** holds your settings profiles (keyed by character name and realm) and
  the [probe](#the-probe-file).
- **`!BugGrabber.lua`** holds error messages from every addon, with file paths and stack traces.

Neither contains your password or account details. They do name your characters and realm. Feel
free to replace those with placeholders before posting.

### The probe file

The probe records what the client let Forever Druid read: a snapshot at login, one shortly after
your first fight, and one each time you run `/fd probe`. Each snapshot holds:

- **Character:** client version, your class, race, level, form, role and talent points per tree.
- **Visibility:** which power types, buffs and cooldowns were hidden.
- **Tests:** the results of the in-combat capability checks.
- **Inventory and counters:** reagent counts, your spellbook (out of combat), per-feature counters
  and Forever Druid's CPU use.

Turn automatic snapshots off under Diagnostics.
