# Commands and key bindings

`/fd` and `/foreverdruid` do the same thing. `/fd` on its own prints this list in game.

## Everyday

| Command | Does |
|---|---|
| `/fd config` | Open the settings (Options > AddOns > ForeverDruid) |
| `/fd unlock` / `/fd lock` | Unlock the HUD to move it, lock it again (not in combat) |
| `/fd reset` | Every piece back to its default place and back in the column |
| `/fd grid` | Alignment grid while unlocked, on or off |
| `/fd minimap` | Show or hide the minimap button |
| `/fd status` | Your form, talent line, role, CPU use and which parts are on |
| `/fd tour` | Show the welcome tour again |
| `/fd whatsnew` | Show the latest release notes |

## Layout and parts

| Command | Does |
|---|---|
| `/fd stack on` / `off` | Automatic stacking of the HUD column |
| `/fd toggle <part>` | Turn one part on or off |

Part names for `/fd toggle`: `manabar`, `powerbar`, `fsr` (five-second rule), `energytick`,
`combopoints`, `powershift`, `cooldowns`, `buffs`, `targetauras`, `reminders`, `alerts`,
`nextability`, `party`, `healframes`, `formbar`.

## Cooldowns

| Command | Does |
|---|---|
| `/fd cd add <role> <spell>` | Track an extra spell for a role: `cat`, `bear`, `balance`, `healer`, `feral`, `caster` or `all` |
| `/fd cd remove <role> <spell>` | Stop tracking it |
| `/fd cd list` | Show the spells you've added |

## Macros

| Command | Does |
|---|---|
| `/fd macros` | List the FD macros and their state |
| `/fd macros on` / `off` | Turn macro management on or off (off deletes the FD macros ForeverDruid made, not ones you edited) |
| `/fd macros sync` | Bring the macros up to date now |
| `/fd macros restore` | Overwrite FD macros you edited with ForeverDruid's version (asks first) |

## Spell ranks

| Command | Does |
|---|---|
| `/fd ranks` | Show whether it's on and which spells you keep downranked |
| `/fd ranks on` / `off` | Keep action bars on your highest ranks |
| `/fd ranks now` | Upgrade lower ranks on your bars right now |
| `/fd ranks keep <spell>` | Leave that spell at whatever rank you put on your bars |
| `/fd ranks unkeep <spell>` | Keep it at the highest rank again |

## Profiles

| Command | Does |
|---|---|
| `/fd profile` | Show your profile and the others |
| `/fd profile use <name>` | Use (or create) a profile on this character; `/reload` to apply |
| `/fd profile copy <name>` | Copy another profile's settings into yours; `/reload` to apply |
| `/fd profile reset` | Reset your profile to the defaults; `/reload` to apply |
| `/fd profile delete <name>` | Delete another profile (not the one you're using) |
| `/fd profile export` | A text string of your profile, to share |
| `/fd profile import` | Paste a profile string; it's added as a new profile |

## Diagnostics

| Command | Does |
|---|---|
| `/fd probe` | Record a snapshot of what the client lets the addon read, and print a summary. Saved on `/reload` or logout |

## Key bindings

Under **Key Bindings > AddOns > ForeverDruid**:

- **Unlock / lock the HUD**
- **Quick settings menu**
- **All settings**
