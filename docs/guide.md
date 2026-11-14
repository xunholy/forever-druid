# Player guide

Everything Forever Druid does, roughly in the order you'll meet it. Settings live in
**Options > AddOns > Forever Druid**: a main page plus one page per feature. Hover any option for an
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
- [Aggro radius](#aggro-radius)
- [Group play](#group-play)
- [Reminders and levelling](#reminders-and-levelling)
- [Macros](#macros)
- [Highest spell ranks](#highest-spell-ranks)
- [Item tooltips](#item-tooltips)
- [Form bar](#form-bar)
- [Profiles and sharing](#profiles-and-sharing)
- [Look and feel](#look-and-feel)

## Getting started

On your first login Forever Druid asks **how you play**: levelling, Feral damage, tank, healer or
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
| Combo points | Cat Form |
| Shift pips | Cat and Bear Form |
| Cooldowns | Always (optionally only in combat) |
| Buffs & procs | Whenever one of them is up |

A row that isn't showing takes no room, so the column closes up when you change form, and making
one piece bigger pushes the rest down rather than overlapping.

Separate from the column: **reminders** above your character, **alerts** just above the column,
and the **HoT tracker** to its left. The HUD can fade out of
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
opens from Forever Druid's entry in the minimap addon menu. Shift-click the icon for the full
settings. Drag the icon round the minimap to move it; hide it from its own menu and bring it back
with `/fd minimap`.

## Cat Form

**Energy bar.** Your energy, drawn by the client (addons can't read the number on Forever, but a
bar can display it). Forever's energy refills continuously rather than in two-second ticks, so
there's no tick to time.

**Combo points.** Five pips; all turn red at five.

**Shift pips and the Powershift cue.** One pip per shift back into Cat Form your mana covers (up to
five). With the **Furor** talent, a "Powershift" cue appears in combat when your energy is at or
below the threshold you set (25% by default) and you can afford the shift. Your mana and energy stay hidden from the addon: the game
decides each pip and the cue itself. Thresholds are on the Powershift settings page.

**Mana bar.** Your mana while shapeshifted, coloured blue, orange under a quarter and red when
nearly out, with a mark at the cost of one shift back into your form.

**Let it bleed.** When your Rake or Rip is ticking on an enemy below a health threshold (20% by
default), "Let it bleed - next target" appears above the target row. The game evaluates the
target's health; Forever Druid can't see it, so this is "nearly dead and bleeding", not a
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

## Aggro radius

Every enemy nameplate gets a small dot and the mob's estimated aggro radius, such as `22y`. The dot
is red when you're inside that radius, orange when you might be, yellow when you're within 10 yards
of it (change the margin in its settings) and green when you're clear. Grey means the game gave no
distance reading. Friendly NPCs, enemy players, dead mobs
and neutral (yellow) mobs don't get one; neutral mobs can be switched on.

No game API gives a mob's aggro radius, and no public Forever source lists one, so it starts from
14 yards against a mob of your level, a yard more or less per level of difference, never under 5
or over 45. (The long-standing rule of thumb is 20, but the first pulls measured on Forever all came
out near 13.) A `??` mob shows `24y+`. Mind Soothe and Soothe
Animal take 10 yards off, as Forever's own spell data says.

**Threat, once a mob is fighting.** In a group the same spot switches to your threat on that mob: a
percentage and a colour. In Bear Form green means it's safely on you, yellow that someone is
catching up, orange that you're about to lose it and red that someone else has it; the number is
your lead over the next player (`130%` is 30% ahead). In any other form the colours run the other
way, green for "not on you", and the number is how close you are to pulling it. It's off when
you're alone (every mob is yours) unless you tick **Also when solo**, and it shows nothing where
Forever doesn't share threat.

**While you Prowl** mobs notice you much later than their normal radius, so the markers fade and
the warning sound stays quiet.

Then it learns from Forever itself. Each time a mob comes at you on its own, Forever Druid notes
your distance just before and at the pull; the radius lies between the two. A mob that has pulled
you shows its own measured radius with a star, `24y*`, and after three such pulls mobs you
haven't met use your measured average instead of 14. Only pulls where the mob came for you on its
own count: pulls you started, pulls while you Prowl and mobs that went for someone else are counted
but not kept. `/fd pulls` shows what it has learned and `/fd pulls reset`
starts again.

Your distance is a bracket such as 20–25 yards rather than an exact number, because Forever doesn't
give addons enemy positions; the colour accounts for that (orange means the bracket overlaps the
radius). While you Prowl, mobs only notice you much closer than this; the markers still show the
normal radius.

The markers sit on the nameplates, so they work with Plater and with Blizzard's nameplates, and
they stay up while you're mounted. Druids only, like the rest of Forever Druid.

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
with `/fd macros on`. Forever Druid writes "FD ..." macros into your character's own macro slots
for the spells you know, and adds more as you learn them:

Each is named "FD " plus the spell it casts, in full where that fits the game's 16-character limit
(FD Mark, FD Roots and FD Swift Heal are the short ones). Macros that combine spells are named
for what the button is for: FD Survival, FD Travel, FD Ravage Opener.

| Macro | Does |
|---|---|
| FD Rejuvenation, FD Regrowth, FD Healing Touch | Heal your mouseover, friendly target or yourself. Hold Shift on FD Rejuvenation for Swiftmend |
| FD Mark, FD Thorns, FD Innervate | Buff your mouseover, friendly target or yourself without changing target. Hold Shift on FD Mark for Gift of the Wild |
| FD Rebirth | Bring back your dead mouseover or target: Rebirth in combat, Revive out of it |
| FD Maul, FD Claw | The ability plus auto-attack |
| FD Faerie Fire | Faerie Fire on your mouseover or target, the Feral version in Cat and Bear Form |
| FD Roots, FD Hibernate | Crowd control your mouseover or target; hold Shift for your focus |
| FD Cat Form, FD Bear Form | Into that form from caster or the other form, in one press; never takes you out of it |
| FD Powershift | Leave Cat Form and shift straight back in (Furor's energy); won't break Prowl |
| FD Reshift | Powershift whatever form you're in: Cat back into Cat, Bear back into Bear |
| FD Bear Rejuv | Keep pressing: out of Bear Form, Rejuvenation on you (or your mouseover), back into Bear Form |
| FD Prowl | Tap: off your mount and into Cat Form. Tap: Prowl. Tap while prowling: leave Prowl, staying in Cat Form |
| FD Ravage Opener | Cat Form, then Prowl, then Ravage from stealth, then Shred (Claw before you learn it) |
| FD Barkskin | Barkskin in any form (Forever lets you cast it shifted) |
| FD Swift Heal | Nature's Swiftness into an instant Healing Touch |

These start off, so they don't fill your 30 character macro slots (all of them together would need
45). Tick the ones you want, or pick a play style under "How do you play?" and it ticks the ones
that suit it:

| Macro | Does |
|---|---|
| FD Growl | Growl your mouseover or target without changing target; shifts you into Bear Form first if needed |
| FD Bash | Bash your mouseover or target, or hold Shift for your focus (interrupts); shifts you into Bear Form first if needed |
| FD Maul Lacerate, FD Primal Bite, FD Swipe | Maul on your next swing plus Lacerate, Primal Bite (Forever's high-threat bite) or Swipe in one press, with auto-attack; shifts you into Bear Form first if needed |
| FD Berserk | Berserk, plus Tiger's Fury in Cat Form, in one press; shifts you into Cat Form first if you're in neither form |
| FD Feral Charge | Feral Charge your mouseover or target. Forever's version charges in Bear Form and leaps behind the target in Cat Form; from anything else it shifts you into Bear Form |
| FD Survival | Your best healing potion, Bear Form if you're not in it, then Frenzied Regeneration. Potions work in forms on Forever, so you stay a bear |
| FD Bear Weapon | Equips the weapon in your bags with the most Bear attack power and shifts into Bear Form |
| FD Dash | Into Cat Form if you're not in it, then Dash |
| FD Pounce Opener | The stun opener: Cat Form, Prowl, Pounce, then Rake |
| FD Travel | Aquatic Form in water, Travel Form outdoors, Cat Form indoors. Press again to leave Travel or Aquatic Form; never knocks you out of Cat Form |
| FD Moonkin Form | Into Moonkin Form; never takes you out of it |
| FD Moonfire, FD Insect Swarm | Moonfire or Insect Swarm your mouseover or target, to dot several mobs without retargeting |
| FD Soothe Animal | Soothe the beast under your mouse or your target: its aggro radius shrinks by 10 yards, and the aggro radius markers show it |
| FD Hurricane | Hurricane at your cursor, no targeting circle |
| FD Heal or Wrath | Levelling: Healing Touch on a friend, Wrath on an enemy, Healing Touch on you with no target |
| FD Wild Growth | Wild Growth on your mouseover, friendly target or yourself |
| FD Cleanse | Abolish Poison (Cure Poison before you learn it) on your mouseover, friendly target or yourself; hold Shift for Remove Curse |
| FD Spirit Swap | Equips the highest-Spirit weapon in your bags and Innervates you (Innervate boosts Spirit-based regen). Swap your usual weapon back afterwards |
| FD Healthstone | Your best Healthstone, then your best healing potion on the next press, in any form |
| FD Trinkets | Both trinkets at once |
| FD Next Target | Drop a dead or friendly target, target the nearest enemy, start attacking (never breaks Prowl) |

The potion, Healthstone and weapon macros choose from what's in your bags and update as that
changes. Potions are ranked by how much they heal, so Forever's Discolored potions come first, and
ones too high for your level are skipped.

**Only the forms that block a spell are dropped.** Forever's spell data says which forms each spell
can still be cast in. Heals work in Tree of Life; buffs, Innervate, Rebirth, Revive and the cleanses
work in Moonkin Form and Tree of Life; Hurricane, Moonfire, Wrath and Hibernate work in Moonkin
Form. The macros leave you in those forms and drop the others.

**Why some take two presses.** The game only lets you use Prowl, or a caster spell, once it has
confirmed your form change, and that happens after a key press has finished. So the macros that
drop your form for a caster spell do it in one press when the game updates straight away, and
otherwise drop the form on the first press and cast on the second. They never cast blind or
leave you in a form you didn't ask for, and they never drop Prowl. FD Prowl and FD Powershift
work the same way.

Click **Pick up** next to a macro, then click an action bar slot. If you edit an FD macro,
Forever Druid leaves it alone from then on ("Restore edited macros" puts its version back). It never
touches a macro of yours that happens to share a name, and only deletes an FD macro when you untick
it or turn macro management off. Macro changes wait until you're out of combat.

## Highest spell ranks

Forever has Classic spell ranks, and an action button keeps the rank you put on it. With **Keep my
action bars on the highest rank** on (the default), learning a new rank switches every button with
an older rank of that spell to it, out of combat and never while you're dragging something. To keep
a spell downranked on purpose: `/fd ranks keep Healing Touch`. `/fd ranks now` runs it by hand. The
FD macros don't need this: `/cast` always uses your highest rank.

## Item tooltips

Item tooltips get a Forever Druid section that turns the item's stats into what they do for you,
each followed by the change against what you're wearing in that slot, green when better and red
when worse:

- **Cat and Bear attack power.** Cat is 2 per Strength, 1 per Agility, plus attack power; Bear is 2
  per Strength plus attack power. These are the Classic druid formulas.
- **Crit, hit, haste and dodge chance**, from Agility and from crit, hit, haste and dodge ratings.
- **Health** from Stamina, **armor** including 2 per Agility, and **defense** from defense rating.
- **Mana** and **spell crit chance** from Intellect, **spell hit**, **healing**, **spell damage**,
  **mana per 5** and **Spirit**.

The crit, dodge, spell crit, rating and health rates come from the game, the same ones the
character sheet uses, so they follow your level. Forever sometimes hides those rates from addons;
then the tooltip shows the stat itself instead, such as `Agility +6`. Lines that are zero on both
items are left out. Turn it all off under **Druid values in item tooltips**.

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
