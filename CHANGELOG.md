# Changelog

## 0.5.0

**New**
- "How do you play?": levelling, Feral, tank, healer or Balance switches on the parts that matter,
  sets your role and can create the matching macros. Asked on first login; `/fd style` or the
  minimap menu after that.
- Right-click a piece while unlocked for its settings, hide it, column or own spot, reset its
  position. Hovering explains it.
- Settings open with "At a glance": every part with an on/off box, a status line and a link to its
  page. Pages are in a sensible order; "Party" is now "HoT tracker" and "Heal frames" is
  "Click-to-heal frames".
- Quick menu regrouped; `/fd <part>` opens a part's settings; mistyped commands suggest the
  closest one; grouped `/fd help`.
- Shift pips (how many shifts your mana affords) and a Powershift cue in Cat or Bear Form with
  Furor: energy or rage low, mana enough, and not just before an energy tick. Mana, energy and
  rage stay hidden; the client decides each pip and the cue from them.
- Click-to-heal party frames (off by default) on Blizzard's secure group header: five clicks you
  assign (target, heals, cures, Innervate, Rebirth, buffs), health, your HoTs and range per bar.
- Form bar (off by default): click-to-shift buttons, current form lit, mana costs.
- Item tooltips: Cat and Bear attack power and healing, with the change from your equipped item.
- "Growl missed" when threat shows you still don't have the mob after a Growl.
- Next ability: Blizzard's own rotation suggestion (C_AssistedCombat), shown as an icon by the HUD
  with a glow on the Blizzard action button that holds it. The game picks the spell from values
  addons can't read; nothing shows if the client doesn't offer it, and the probe records why.
- "Let it bleed - next target" above the target row when one of your bleeds or DoTs is ticking on
  an enemy under a health threshold you set (20% by default). The game evaluates the target's
  health itself; ForeverDruid never reads it.
- Party panel (in a group): your HoTs on each member with timers, a Rebirth hint when one is
  dead, and an Innervate hint that fades in when a healer is under about a third of their mana
  (the game does the fade from their hidden mana; the addon never reads it).
- Alerts: Clearcasting and Nature's Grace the moment they trigger, and "Losing aggro!" in Bear
  Form in groups. Each only shows when Forever lets addons read it in combat.
- Missing-debuff icons on enemy targets for your role: Faerie Fire, Demoralizing Roar (Bear),
  Moonfire and Insect Swarm (Balance). Only when the target's debuffs can be identified.
- Unspent talent point reminder; macros FD Faerie, FD Barkskin and FD Swift Heal.
- Highest-rank action bars: when you learn a new rank, every button holding an older rank of
  that spell switches to it (out of combat, never while you're dragging something).
  `/fd ranks keep <spell>` leaves a spell downranked on purpose; `/fd ranks now` runs it by hand.
- Energy bar in Cat Form and rage bar in Bear Form, with the energy tick spark on the bar.
- Five-second-rule bar after every mana-costing cast.
- Choose your caster-form role (auto, healer, Balance, Feral). A talent split within two points
  now counts as Feral.
- Reminders for a trainer visit after each even level and for the Bear Form (10) and Cat Form
  (20) class quests. Optional reagent restock at vendors (off by default: it spends gold).
- Macro manager: turn it on and ForeverDruid creates druid macros in your character's own slots
  (Rejuvenation, Regrowth and Healing Touch that drop your form first, mouseover Mark of the Wild,
  Thorns and Innervate, Maul and Claw with auto-attack, Cat and Bear powershifts, mouseover
  Entangling Roots, Hibernate and Rebirth, Prowl into Ravage). Each one appears when you learn its
  spells. Untick one to delete it; edit one and ForeverDruid leaves it alone. Pick them up from
  the Macros settings page or the minimap menu. `/fd macros on | off | sync | restore`.
- Unlocking fills empty rows with sample buffs, DoTs, combo points and reminders, so you can see
  what you're arranging. Arrow keys nudge the piece under your mouse (Shift: 10px), and an
  optional grid marks the screen centre.
- Cooldowns flash when they come back, dim when you can't use them, turn blue when you're short on
  mana, rage or energy, and red when your target is out of range. Works in combat.
- Minimal or Blizzard-style icons, outlined countdown numbers, and a mana bar that glides.
- Welcome tour on first install and a "What's new" window after updates (never during a fight).
- Settings split into a page per part of the HUD, with a tooltip on every option. Resetting
  positions or a profile asks first.
- Key bindings under Key Bindings > AddOns: unlock, quick settings, all settings.
- Share a profile as a text string and import someone else's as a new profile.
- German, French and Spanish translations of the menus, settings and welcome tour.
- `/fd status` and the probe report ForeverDruid's own CPU use when the game's profiler is on.

## 0.4.0

**New**
- Minimap button. Left-click opens quick settings: turn any part of the HUD on or off, HUD size,
  fading out of combat, hide while mounted, mana bar text and forms, which reminders you get
  (Thorns never / in Bear Form / always), profiles, reset positions. Right-click unlocks the HUD
  for moving, shift-click opens all settings. Drag it to move it round the minimap.
- The minimap addon menu entry opens the same quick settings.
- Hide the button from its own menu or the options; `/fd minimap` brings it back.

## 0.3.0

**New**
- The HUD arranges itself into one column under your character. Pieces that aren't showing take
  no room, so changing form no longer leaves gaps, and making something bigger pushes the rest down
  instead of overlapping.
- Drag any piece to move the whole column. Shift-drag one to give it a spot of its own; "Part of
  the stack" in the options puts it back.
- Options: turn automatic stacking off, and set the space between pieces. `/fd stack on | off`.
- `/fd reset` also puts every piece back in the column.

**Fixed**
- Omen of Clarity can't be cast on Forever, so a reminder for it would never clear. Reminders now
  skip any spell the spellbook marks as passive, and the probe records which spells those are.

## 0.2.0

Built from what the 0.1.0 probe recorded on a live Forever client (1.60.1.70790): your mana, rage
and energy are hidden from addons even out of combat, maximums and combo points are readable, and
auras are hidden in combat.

**New**
- Combo point pips under the HUD, turning red at five points.
- Buffs & procs row: Clearcasting, Tiger's Fury, Barkskin, Nature's Grasp, Enrage, Frenzied
  Regeneration, Innervate, Dash and Nature's Swiftness, with timers.
- My effects on target: your DoTs on an enemy, or your HoTs on a friend, with timers that keep
  running in combat.
- Reminders are clickable: click Mark of the Wild, Thorns, Omen of Clarity or the ley line reminder
  to cast it.
- Thorns reminder in Bear Form (on by default); the all-forms Thorns reminder stays optional.
- Cooldown row: Faerie Fire (Feral), Feral Charge, Starfall, Force of Nature and Nature's Grasp,
  your Skyborne racials (Read Leyline, Walk on Air), countdown numbers, optional tooltips, and your
  own spells via `/fd cd add <role|all> <spell>`.
- Mana bar colours itself by mana level, can show a percentage, and marks what one shift costs.
- Profiles shared across characters: `/fd profile`.
- Full options panel (Options > AddOns > ForeverDruid) with sliders for size and scale.
- ForeverDruid in the minimap addon menu: left-click for options, right-click to unlock.
- Fade the HUD out of combat, and hide it while mounted, dead or on a taxi.

**Fixed**
- The energy tick timer couldn't learn on Forever because energy is never readable. It now works
  from the timing of energy updates and ignores the ones caused by your own casts.
- The Skyborne ley line reminder used the wrong spell name. It now uses Read Leyline (1259705) and
  the Attuned buff (1259691).
- Unlocking, locking and resetting positions are refused in combat instead of failing.

**Changed**
- Settings moved from per-character storage into profiles. Your 0.1.0 settings carry over.

## 0.1.0

First version: mana bar in Cat/Bear Form, energy tick timer, role-aware cooldown row, buff and
reagent reminders, Skyborne ley line reminder, and the diagnostic probe.
