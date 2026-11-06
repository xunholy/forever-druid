# Player guide

Everything ForeverDruid does, roughly in the order you'll meet it. Settings live in
**Options > AddOns > ForeverDruid**: a main page plus one page per feature. Hover any option for an
explanation. The [commands page](commands.md) lists the slash commands.

- [Getting started](#getting-started)
- [The HUD column](#the-hud-column)
- [Moving and arranging](#moving-and-arranging)
- [Cat Form](#cat-form)
- [Bear Form](#bear-form)
- [Caster form: healing and Balance](#caster-form-healing-and-balance)
- [Your target](#your-target)
- [Cooldowns](#cooldowns)
- [Buffs, procs and alerts](#buffs-procs-and-alerts)
- [Next ability](#next-ability)
- [Group play](#group-play)
- [Reminders and levelling](#reminders-and-levelling)
- [Macros](#macros)
- [Highest spell ranks](#highest-spell-ranks)
- [Item tooltips](#item-tooltips)
- [Form bar](#form-bar)
- [Profiles and sharing](#profiles-and-sharing)
- [Look and feel](#look-and-feel)

## Getting started

On your first login ForeverDruid asks **how you play**: levelling, Feral damage, tank, healer or
Balance. Your choice switches on the parts that matter for it and off the rest, sets your
caster-form role and (if you leave the box ticked) creates the matching macros. Then a short tour
shows where things are. Change your mind any time: **Play style** in the minimap menu, **Choose how
you play...** in the settings, or `/fd style`.

The main settings page opens with **At a glance**: every part with an on/off box, a one-line status
("learning in Cat Form", "not offered by this client", "7 created") and a button to its own page.
`/fd <part>` jumps straight to a part's page, for example `/fd heal` or `/fd macros`.

## The HUD column

The combat HUD forms one centred column under your character. From top to bottom:

| Row | When it shows |
|---|---|
| My effects on target | Whenever you have a target |
| Energy / rage | Cat Form (energy) and Bear Form (rage) |
| Mana bar | Cat and Bear Form (caster form already has Blizzard's) |
| Five-second rule | Always, as a thin row; fills after you spend mana |
| Energy tick | Cat Form, once ticks are learned, when the energy bar isn't carrying the spark |
| Combo points | Cat Form |
| Shift pips | Cat and Bear Form |
| Cooldowns | Always (optionally only in combat) |
| Buffs & procs | Whenever one of them is up |

A row that isn't showing takes no room, so the column closes up when you change form, and making
one piece bigger pushes the rest down rather than overlapping.

Separate from the column: **reminders** above your character, **alerts** just above the column,
**Next ability** to its left, and the **HoT tracker** further left. The HUD can fade out of
combat (off by default) and hides while you're mounted, dead, on a taxi or in a vehicle.

## Moving and arranging

Right-click the minimap icon, or type `/fd unlock`. Every piece shows a green box with its name,
filled with sample icons so empty rows have something to place.

- **Drag any piece in the column** to move the whole column.
- **Shift-drag a piece** to pull it out and give it a spot of its own. Put it back with
  "Part of the stack" on its settings page, or `/fd reset`.
- **Hover a piece and use the arrow keys** to nudge it one pixel (Shift: ten).
- **`/fd grid`** shows an alignment grid with the screen centre marked.

**Right-click a piece** (while unlocked) for its own menu: its settings, hide it, give it its own
spot or put it back in the column, reset its position. Hovering a piece explains what it shows.

Lock again with another right-click on the minimap icon or `/fd lock`. You can't unlock or lock during combat. Key
bindings for unlock, the quick menu and the settings panel are under **Key Bindings > AddOns**.

**Quick settings.** Left-click the minimap icon for a menu covering most day-to-day changes: play
style, unlock and role at the top, then grouped submenus for HUD parts, look, forms, reminders,
spells and macros, and profiles. The same menu
opens from ForeverDruid's entry in the minimap addon menu. Shift-click the icon for the full
settings. Drag the icon round the minimap to move it; hide it from its own menu and bring it back
with `/fd minimap`.

## Cat Form

**Energy bar.** Your energy, drawn by the client (addons can't read the number on Forever, but a
bar can display it). With "Energy tick spark on the bar" on, it carries the tick spark itself.

**Energy tick.** Forever doesn't tell addons your energy, so ForeverDruid learns the tick timing
from *when* energy updates arrive, ignoring the ones caused by your own abilities. It needs a few
fights in Cat Form before the spark appears. If Forever regenerates energy continuously instead of
in ticks, it detects that and stays hidden.

**Combo points.** Five pips; all turn red at five.

**Shift pips and the Powershift cue.** One pip per shift back into Cat Form your mana covers (up to
five). With the **Furor** talent, a "Powershift" cue appears in combat when your energy is at or
below the threshold you set (25% by default), you can afford the shift, and the next energy tick
isn't due in the next 0.6 seconds. Your mana and energy stay hidden from the addon: the game
decides each pip and the cue itself. Thresholds are on the Powershift settings page.

**Mana bar.** Your mana while shapeshifted, coloured blue, orange under a quarter and red when
nearly out, with a mark at the cost of one shift back into your form.

**Let it bleed.** When your Rake or Rip is ticking on an enemy below a health threshold (20% by
default), "Let it bleed - next target" appears above the target row. The game evaluates the
target's health; ForeverDruid can't see it, so this is "nearly dead and bleeding", not a
guarantee. Tune the threshold on the target settings page.

## Bear Form

**Rage bar,** with Enrage, Bash, Frenzied Regeneration, Feral Charge and Barkskin on the cooldown
row. Shift pips and the Powershift cue work here too: with Furor, re-shifting gives 10 rage, and the
cue shows when rage is at or below 10%.

**Losing aggro.** In a group, "Losing aggro!" when someone is about to pull a mob off you, or just
after you lose one you were holding. Mobs another tank is meant to hold don't trigger it. Tick
"Also when solo" if you want it outside groups.

**Growl missed.** "Growl missed - taunt again!" when the mob still isn't on you shortly after a
Growl.

Both depend on Forever letting addons read threat. If it doesn't, they stay silent.

## Caster form: healing and Balance

Your caster-form role decides the cooldown row. By default it comes from your talents (a split
within two points counts as Feral, since that's usually a levelling druid); pick Healer, Balance
or Feral yourself under **Role** in the settings or the quick menu. Cat and Bear Form always use
their own role.

**Five-second rule.** Spending mana pauses your normal mana regeneration for five seconds. A thin
bar fills over those five seconds after each mana-costing cast.

**Healer:** Nature's Swiftness, Swiftmend, Tranquility, Innervate and Rebirth on the cooldown row,
plus the [HoT tracker](#group-play).

**Balance:** Starfall, Force of Nature, Hurricane, Nature's Swiftness; Nature's Grace alerts;
warnings when Faerie Fire, Moonfire or Insect Swarm are missing from your target.

## Your target

**My effects on target** shows your DoTs on an enemy (Rake, Rip, Moonfire, Insect Swarm, Faerie
Fire) or your HoTs on a friend (Rejuvenation, Regrowth), with timers that keep running in combat.

**Missing debuffs.** In combat, a dimmed red-framed icon for what your role should keep on an
enemy: Faerie Fire (Cat), Demoralizing Roar and Faerie Fire (Bear), Faerie Fire, Moonfire and
Insect Swarm (Balance). Another druid's Faerie Fire or a warrior's Demoralizing Shout counts. It
only shows when the game lets addons name the target's debuffs, and a target immune to a debuff
will keep showing it.

## Cooldowns

The row shows cooldowns for your current role, limited to spells you know, plus the Skyborne
racials Read Leyline and Walk on Air. Each icon:

- flashes when its cooldown comes back
- dims when you can't use it right now
- turns blue when you're short on mana, rage or energy for it
- turns red when your target is out of range for it

These use the client's own checks, so they work in combat. Add your own spells with
`/fd cd add <role|all> <spell name>`, for example `/fd cd add bear Challenging Roar`.

## Buffs, procs and alerts

**Buffs & procs** shows Clearcasting, Tiger's Fury, Barkskin, Enrage, Frenzied Regeneration,
Nature's Grasp, Innervate, Dash and Nature's Swiftness with timers. Forever hides buffs from addons
during combat, so a buff already up when the fight starts stays shown, dimmed, until it would have
run out; one gained mid-fight appears once combat ends.

**Alerts** show Clearcasting and Nature's Grace as a large icon the moment they trigger, when the
game names the buff as it's gained (it may not on Forever; the probe records whether it does).
Optional sound.

## Next ability

When Forever's client offers Blizzard's rotation helper, an icon left of the HUD shows the ability
it suggests next during combat, and the button on your Blizzard action bars that holds it glows.
The game picks the spell from your real energy, buffs and target state; the addon only shows the
answer. If the client doesn't offer the helper, nothing shows, and the Next ability settings page
says why. Buttons from other action bar addons aren't found.

## Group play

**HoT tracker** (on in a group). One row per member and you, with your HoTs and their timers. A
Rebirth icon appears next to someone who's dead, and an Innervate icon fades in next to a healer
under about a third of their mana. Their mana is hidden from the addon; the game applies the fade.

**Click-to-heal frames** (off by default, on with the Healer play style; or turn on from their
settings page or the quick menu's "HUD parts"). You and your party as click-to-heal bars with health, your HoTs and an out-of-range
shade. Choose what each click casts:

| Click | Default |
|---|---|
| Left | Rejuvenation |
| Right | Regrowth |
| Middle | Nothing |
| Shift + left | Healing Touch |
| Shift + right | Remove Curse |

"Target them" is available on left and right click. Spells you haven't learned are skipped. All
five frames are prepared out of combat, so someone joining mid-fight can be clicked straight away;
click settings you change in combat apply when it ends. Move the frames with the buttons on their
settings page.

## Reminders and levelling

Out of combat, icons above your character for:

- missing **Mark of the Wild**, **Thorns** (in Bear Form by default; or always, or never), and
  **Omen of Clarity** where it's a castable buff (on Forever it isn't)
- low **Rebirth seeds** or **Gift of the Wild reagents**
- **Skyborne:** not attuned to a ley line (click to Read Leyline)
- a **trainer visit** after each even level, until you open a druid trainer
- **unspent talent points**
- the **Bear Form** (level 10) and **Cat Form** (level 20) class quests, until you have the form

Click a buff reminder to cast it, or **right-click** to hide it for 30 minutes. The trainer,
class-quest and talent reminders go away with **any click**: the trainer one until your next even
level, a class quest until your next level, talent points until the number changes.

**Reagent restock** (off by default, because it spends gold):
opening a vendor that sells them tops up the seed for your Rebirth rank and your Gift of the Wild
reagent to the amounts you set, only what you can afford.

## Macros

Turn on **Create and update my druid macros** on the Macros settings page, in the quick menu, or
with `/fd macros on`. ForeverDruid writes "FD ..." macros into your character's own macro slots
for the spells you know, and adds more as you learn them:

| Macro | Does |
|---|---|
| FD Rejuv, FD Regrowth, FD Heal Touch | Heal your mouseover, friendly target or yourself, dropping your form first |
| FD Mark, FD Thorns, FD Innervate | Buff your mouseover, friendly target or yourself without changing target |
| FD Rebirth | Rebirth your dead mouseover or target |
| FD Maul, FD Claw | The ability plus auto-attack |
| FD Faerie | Faerie Fire on your mouseover or target, the Feral version in Cat and Bear Form |
| FD Roots, FD Hibernate | Crowd control your mouseover or target, dropping your form first |
| FD Shift Cat, FD Shift Bear | Into that form from caster or the other form, in one press; never takes you out of it |
| FD Powershift | Leave Cat Form and shift straight back in (Furor's energy); won't break Prowl |
| FD Prowl | Tap: Cat Form. Tap: Prowl. Tap while prowling: leave Prowl, staying in Cat Form |
| FD Opener | Cat Form, then Prowl, then Ravage from stealth |
| FD Barkskin | Barkskin, dropping your form first |
| FD Swift Heal | Nature's Swiftness into an instant Healing Touch |

**Why some take two presses.** The game only lets you use Prowl, or a caster spell, once it has
confirmed your form change, and that happens after a key press has finished. So the macros that
drop your form for a caster spell do it in one press when the game updates straight away, and
otherwise drop the form on the first press and cast on the second. They never cast blind or
leave you in a form you didn't ask for, and they never drop Prowl. FD Prowl and FD Powershift
work the same way.

Click **Pick up** next to a macro, then click an action bar slot. If you edit an FD macro,
ForeverDruid leaves it alone from then on ("Restore edited macros" puts its version back). It never
touches a macro of yours that happens to share a name, and only deletes an FD macro when you untick
it or turn macro management off. Macro changes wait until you're out of combat.

## Highest spell ranks

Forever has Classic spell ranks, and an action button keeps the rank you put on it. With **Keep my
action bars on the highest rank** on (the default), learning a new rank switches every button with
an older rank of that spell to it, out of combat and never while you're dragging something. To keep
a spell downranked on purpose: `/fd ranks keep Healing Touch`. `/fd ranks now` runs it by hand. The
FD macros don't need this: `/cast` always uses your highest rank.

## Item tooltips

Item tooltips get a ForeverDruid section with the item's Cat attack power (2 per Strength, 1 per
Agility, plus attack power), Bear attack power (2 per Strength plus attack power) and healing,
followed by the change against what you're wearing in that slot, green when better and red when
worse. These are the Classic druid formulas. Turn it off under **Druid values in item tooltips**.

## Form bar

Off by default. A row of your forms next to the HUD: click to shift, the current form is lit, and
each shows its mana cost. It's rebuilt out of combat when you learn a form.

## Profiles and sharing

Settings are stored in profiles shared across characters; everyone starts on `Default`.
`/fd profile use Tank` puts a character on its own profile (after `/reload`). See
[commands](commands.md#profiles) for copy, reset and delete.

**Share this profile...** on the main settings page (or `/fd profile export`) gives you a text
string; **Import a profile...** adds someone else's string as a new profile without touching
yours. Imports are checked setting by setting, and never switch on anything that spends gold or
changes your macros and action bars.

## Look and feel

- **Icon style:** minimal (cropped with a thin frame) or Blizzard (the icon's own border)
- **Overall scale**, and a scale per part of the HUD
- **Opacity out of combat:** fully visible, faded, faint or hidden
- **Hide while mounted**
- **Smooth bars:** mana, energy and rage glide to new values

German, French and Spanish translations cover the menus, settings and welcome tour.
