# How Forever Druid works on Forever

WoW Forever runs on the modern (Midnight) game client with Classic gameplay. That client keeps a lot
of combat information away from addons. This page explains what's hidden, how Forever Druid still
shows it, and what no addon can do on Forever. It's why some familiar druid addons don't work
here, and why a few Forever Druid features are thresholds you tune rather than exact numbers.

## Hidden values

Some numbers reach addons as **hidden values**. An addon can hand a hidden value to one of the
game's own widgets (a bar, a text label, a cooldown spiral, an icon's transparency) and the game
draws it. What the addon can't do is look at it: compare it, do arithmetic on it, test it, or turn
it into text. Any attempt raises an error.

Forever Druid's probe recorded this on the launch client (1.60.1, build 70790):

| Information | Readable by addons? |
|---|---|
| Your mana, rage and energy | Hidden, **even out of combat** |
| Your maximum mana, rage and energy | Readable |
| Combo points | Readable |
| Your buffs and debuffs | Readable out of combat, hidden in combat |
| Spell cooldowns | Readable out of combat, hidden in combat |
| A target's health | Hidden (per the client's API documentation) |
| The combat log | Restricted (per the client's API documentation) |

## How Forever Druid shows hidden things

**Hand the value straight to a widget.** The energy, rage and mana bars, the numbers on them, buff
and DoT icons and their timers, and the party frames' health bars all take the hidden value as
it is, and the game draws it. Cooldown spirals use the client's "duration objects", which draw
correctly in combat (the probe recorded zero failures).

**Let the game decide, with a curve.** The client can evaluate a hidden percentage against a curve
the addon supplies, and pass the result, still hidden, to a widget. Forever Druid uses that for any
"show this below X%" feature:

- the mana bar's colour and percentage
- the shift pips (one curve per pip, stepping at one, two, three... shifts' worth of mana)
- the Powershift cue: an outer frame faded by an "energy is low" curve, an inner frame faded by a
  "mana covers the shift" curve. The game multiplies the two transparencies, so the cue only shows
  when both are true. Forever Druid never learns either answer.
- "Let it bleed" (the target's health under your threshold)
- the Innervate hint (a healer's mana under about a third)

**Use the client's own yes/no answers.** "Is this spell usable?", "is the target in range?" and
"am I short on power?" come back as hidden booleans. The game can colour a texture from a hidden
boolean, which is how the cooldown icons' dim, blue and red tints work in combat.

**Check, then stay quiet.** Some features need information Forever may or may not hide: whether a
gained buff is named in combat (proc alerts), whether threat is readable (aggro and Growl
warnings), whether a target's debuffs can be identified (missing debuffs). Each one checks at the
moment it's needed and shows nothing if the answer is hidden. It never guesses. The probe counts
how often each check succeeds.

## What no addon can do on Forever

- **Exact "will this bleed kill it" or time-to-die.** That needs the target's health as a number
  and the rate it's falling. Addons get neither. "Let it bleed" is the closest possible version.
- **Swing timers, threat meters, damage meters.** These are built on the combat log, which Forever
  restricts for addons.
- **Rotation helpers.** Anything that checks "energy above 40" or "Rip has under 2 seconds left"
  in Lua errors on Forever, which is why MaxDps throws constant errors here. Blizzard's own
  rotation helper, which does the maths inside the game, isn't offered on Forever either.
- **Energy tick timers.** Forever's energy refills continuously, not in two-second ticks, so
  there's nothing to time.
- **Exact shift counts.** Shift pips can show you have "at least three", but the addon can't read
  that number back to, say, write it in chat.

## Confirmed in game

From probe snapshots and bug logs on the launch client:

- the visibility table above
- cooldown spirals from duration objects (zero failures)
- talent points per tree, Skyborne spell IDs, Omen of Clarity being a passive rather than a buff
  you cast
- energy refilling continuously (no ticks), and Blizzard's rotation helper not being offered
- threat being readable (the probe got real answers)
- several sessions with Forever Druid enabled and no errors from it

**Not yet seen in a real session** (built and tested against a model of the client, awaiting play):

- whether the curve-based features draw as intended
- the usable, power and range tints
- proc alerts
- the aggro and Growl warnings
- missing-debuff icons
- the heal frames

The probe records each of these, so the next round of fixes comes from real data. If you play a
druid on Forever, sharing your probe file helps; see [reporting a bug](troubleshooting.md#reporting-a-bug).

## Where the facts come from

- **Probe:** Forever Druid's probe records what the live client allows. Its file is described in
  [troubleshooting](troubleshooting.md#the-probe-file).
- **API documentation:** API behaviour was checked against Blizzard's interface source for Forever
  (the `forever` branch of the community mirror at
  [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source)), which includes the client's API
  documentation. That's where "hidden returns", "restricted" and "allowed with hidden arguments"
  come from.
