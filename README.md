# ForeverDruid

A druid addon for World of Warcraft: Forever (client 1.60.x, interface 16001). It's one addon in
place of the usual pile (mana bar, combo bar, cooldown tracker, buff watcher, DoT timers, buff
reminders), laid out for whatever you're doing right now: cat, bear, Balance, Restoration, or a
feral spec standing in caster form.

## What you get

| Module | Shows |
|---|---|
| Mana bar | Your mana in Cat and Bear Form, which Forever's player frame doesn't show there. Turns orange then red as you run low, and has a tick mark for what one shift back into your form costs. |
| Energy tick | A spark that sweeps to the next energy tick in Cat Form, for timing Shred and powershifts. |
| Combo points | Five pips that turn red at five points. |
| Cooldowns | The cooldowns for your current role, limited to spells you know, plus Read Leyline and Walk on Air. Add your own with `/fd cd add`. |
| Buffs & procs | Clearcasting, Tiger's Fury, Barkskin, Nature's Grasp, Enrage, Frenzied Regeneration, Innervate, Dash and Nature's Swiftness, with timers. |
| My effects on target | Your DoTs on an enemy (Rake, Rip, Moonfire, Insect Swarm, Faerie Fire, Lacerate…) or your HoTs on a friend (Rejuvenation, Regrowth…). |
| Reminders | Out of combat: missing Mark of the Wild, Omen of Clarity, Thorns (in Bear Form by default), low Rebirth seeds or Wild Thornroot, and the Skyborne Attuned buff. Click one to cast it. |

The role comes from your form first (Cat, Bear), then from the talent tree with the most points.

## Commands

```
/fd config                        options panel (also Options > AddOns > ForeverDruid)
/fd unlock | lock                 drag things around
/fd reset                         default positions, everything back in the stack
/fd stack on | off                automatic stacking
/fd minimap                       show or hide the minimap button
/fd macros [on|off|sync|restore]  create and manage druid macros
/fd grid                          alignment grid while unlocked
/fd tour | whatsnew               welcome tour, recent changes
/fd profile export | import       share a profile as text
/fd toggle <module>               manabar energytick combopoints cooldowns buffs targetauras reminders
/fd cd add|remove <role|all> <spell>
/fd cd list
/fd profile [list | use <name> | copy <name> | reset | delete <name>]
/fd status                        form, talent line, role, modules
/fd probe                         record what this client exposes
```

## Layout

The combat HUD arranges itself: target effects, mana bar, energy tick, combo points, cooldowns
and buffs form one column under your character. Anything not showing right now (combo points in
Bear Form, the mana bar in caster form, a module you turned off) takes no room, and a piece you
make bigger pushes the rest down rather than overlapping them.

`/fd unlock`, then drag any piece to move the whole column. Shift-drag a piece to pull it out
and give it a spot of its own; tick "Part of the stack" for it in `/fd config` to put it back.
Reminders sit above your character on their own, because their click-to-cast buttons can't be
attached to something that moves during a fight.

## Arranging

Unlock (minimap right-click, `/fd unlock`, or a key binding) and every piece shows a green box
filled with sample icons. Drag any stacked piece to move the column, shift-drag to pull one out,
or hover a piece and use the arrow keys (Shift for 10px). `/fd grid` adds an alignment grid.

## Settings

Options > AddOns > ForeverDruid has a main page (moving, look, profiles, help, diagnostics) and a
page for each part of the HUD. Hover any option for what it does. Key bindings for unlock, the
quick menu and the settings are under Key Bindings > AddOns.

## Macros

Options > AddOns > ForeverDruid > Macros (or the minimap menu): tick "Create and update my druid
macros" and ForeverDruid writes "FD ..." macros into your character's own macro slots for the
spells you know, adding more as you learn them. Click Pick up and then an action bar slot to place
one. It never touches a macro you've edited or one of your own that happens to share a name, and
it only deletes an FD macro when you untick it or turn the feature off. Macro changes wait until
you're out of combat.

## Minimap button

Left-click for quick settings (what's shown, size, fading, forms, reminders, profiles),
right-click to unlock the HUD, shift-click for every setting. Drag it round the minimap to move
it. The same quick settings open from ForeverDruid's entry in the minimap addon menu.

Profiles are shared across characters. Everyone starts on `Default`; `/fd profile use Tank` gives a
character its own (takes effect after `/reload`).

## How it works with Forever's restrictions

Forever uses Midnight's addon rules. The probe found that on 1.60.1.70790 your mana, rage and
energy are hidden from addons even out of combat, maximums and combo points are readable, auras
are hidden in combat, and cooldowns are hidden in combat. Addons may hand hidden values to
Blizzard's widgets to display but can't compare them, do maths on them or test them. So:

- **Mana bar:** the bar and `current / max` text take the raw values. Percentage and low-mana
  colour come from `UnitPowerPercent` evaluated against a curve, which the client computes. The
  shift marker uses the form's mana cost and your maximum mana, both readable.
- **Energy tick:** the value is never readable, so it learns from *when* energy updates arrive,
  ignoring the ones right after your own casts, and keeps the phase going while energy is full.
  If regen turns out to be continuous, the bar stays hidden.
- **Cooldowns:** duration objects (`C_Spell.GetSpellCooldownDuration` →
  `Cooldown:SetCooldownFromDurationObject`), drawn by the client.
- **Buffs, procs and target effects:** icons and timers go straight from the aura data into
  `Texture:SetTexture` and `Cooldown:SetCooldownFromExpirationTime`. When the client refuses to
  say whether a buff is still up in combat, its icon stays as last seen, dimmed.
- **Reminders:** out of combat only, as secure buttons, changed only outside combat lockdown.

API behaviour was checked against Blizzard's Forever UI source (`Gethe/wow-ui-source`, branch
`forever`, build 1.60.1.70790).

## The probe

The probe records what the client actually lets addons read: a snapshot at login, one after the
first pull of each session, and one on `/fd probe`. They're written on logout or `/reload` to

```
_forever_/WTF/Account/<ACCOUNT>/SavedVariables/ForeverDruid.lua
```

It includes which power types and auras are hidden, energy event timing, which spell IDs
Forever uses, reagent counts and per-module counters. Turn it off under Diagnostics in the options.

## Development

```
lua tests/run.lua        # runs the addon against a WoW Forever API stub
luacheck .               # lint (config in .luacheckrc)
scripts/deploy.sh        # lint and tests, then copies ForeverDruid/ into the Forever AddOns folder
scripts/package.sh       # tests, then builds dist/ForeverDruid-<version>.zip
```

CI runs the same lint and tests on GitHub; `docs/PUBLISHING.md` covers releases. See
`tests/README.md` for what the stub models.

The stub's hidden values raise errors on comparison, arithmetic, concatenation, indexing, calling
and `tostring`, like the real client. Its secure buttons refuse changes during combat lockdown.
What it can't catch: Lua won't let a stub intercept `==` against a non-table or a plain truthiness
test, so code checks `ns.IsSecret` before either. That's enforced by review, not by the tests.

MIT licensed.
