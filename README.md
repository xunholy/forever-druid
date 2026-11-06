# ForeverDruid

A druid addon for **World of Warcraft: Forever** (client 1.60, interface 16001). One addon in place
of the usual stack of druid add-ons: a mana bar for your forms, energy and combo points, cooldowns,
procs, your DoTs and HoTs, buff reminders, powershifting help, macros, click-to-heal party frames,
and a "next ability" helper. It's built around what Forever's client actually lets addons see,
which is less than Classic allowed.

It changes with your form. Shift into Cat Form and the column under your character becomes energy,
combo points, the energy tick and your bleeds; Bear Form swaps in rage and your tanking cooldowns;
caster form shows healing or Balance cooldowns, depending on your talents or the role you pick.

> **Status:** 0.5.0, in active development and playtesting on Forever's launch client. Everything is
> covered by an automated test suite against a model of the client, but a lot of it is newer than
> any real play session. See [what's confirmed in game](docs/forever-restrictions.md#confirmed-in-game).

## What's in it

**In Cat Form.** Energy bar with a tick spark that learns Forever's energy timing from the game
itself. Five combo pips that turn red at five. Shift pips showing how many powershifts your mana
still covers, and a "Powershift" cue when energy is low, the shift is affordable and the next tick
isn't about to land (with Furor). Your Rake and Rip on the target with timers, and "Let it bleed -
next target" when a bleeding mob is nearly dead.

**In Bear Form.** Rage bar, Enrage, Bash, Frenzied Regeneration and Feral Charge on the cooldown
row, "Losing aggro!" when a mob turns to someone else in a group, "Growl missed" when a taunt
doesn't take, and a dimmed icon when Demoralizing Roar or Faerie Fire is missing from your target.

**Healing and Balance.** A party panel with your HoTs on each member, a Rebirth hint when someone
dies and an Innervate hint when a healer runs low. Optional click-to-heal party frames where you
choose what each click casts. Clearcasting and Nature's Grace alerts, a five-second-rule bar, and
Moonfire and Insect Swarm upkeep warnings for Balance.

**Everywhere.**
- A cooldown row for your current role that flashes when something comes back and tints itself
  when a spell is out of range, unusable or short on mana, rage or energy
- Click-to-cast reminders for Mark of the Wild, Thorns, low reagents and (for Skyborne) your ley
  line, plus trainer visits, unspent talent points and the Bear and Cat Form class quests
- Druid macros written for you and kept up to date as you learn spells, and action bars kept on
  your highest spell ranks
- Item tooltips showing Cat and Bear attack power and healing, compared with what you're wearing
- Next ability: Blizzard's own rotation suggestion, with a glow on the button to press, when the
  client offers it
- Optional reagent restock at vendors, and an optional click-to-shift form bar

Everything is arranged from a minimap button: drag the whole HUD, pull pieces out, turn parts on
and off, change size and fading. Profiles can be shared as a text string.

## Install

1. Download the latest `ForeverDruid-*.zip` from [Releases](../../releases).
2. Extract the `ForeverDruid` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
3. Start the game (a `/reload` isn't enough for a first install) and tick ForeverDruid in the AddOns
   list at character select.

A short welcome tour opens on your first login. After that: click the cat icon on your minimap for
quick settings, right-click it to move things, shift-click it for everything else.

**Turn off overlapping addons.** ForeverDruid replaces druid mana bars, combo bars and rotation
helpers. MaxDps in particular doesn't work on Forever's client (it errors constantly on hidden
values).

## Documentation

| | |
|---|---|
| [Player guide](docs/guide.md) | Every feature, what it shows and how to set it up |
| [Commands and key bindings](docs/commands.md) | All `/fd` commands |
| [How it works on Forever](docs/forever-restrictions.md) | What the client hides from addons, how ForeverDruid works around it, and what can't be done |
| [Troubleshooting](docs/troubleshooting.md) | When something doesn't show, and how to report a bug |
| [Development](docs/development.md) | Code layout, the test stub, rules for working with hidden values |
| [Changelog](CHANGELOG.md) | What changed in each version |

## Reporting a problem

Open an [issue](../../issues/new/choose) with what you saw and, if you can, two files from
`_forever_/WTF/Account/<your account>/SavedVariables/`: `ForeverDruid.lua` (your settings plus the
probe, a record of what the client let the addon read) and `!BugGrabber.lua` if you use BugSack.
Both name your characters and realm; [Troubleshooting](docs/troubleshooting.md#reporting-a-bug)
explains what's in them and what to blank out before posting.

## License

MIT. See [LICENSE](LICENSE).
