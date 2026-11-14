# Contributing

Bug reports from real Forever sessions are the most useful thing you can send: a lot of
Forever Druid is tuned from what the live client actually allows, and that only shows up in play.

## Reporting

Use the issue templates. For anything that looks wrong in game, attach your `ForeverDruid.lua`
SavedVariables file (it holds the probe) and BugSack's `!BugGrabber.lua` if you have errors.
[Troubleshooting](docs/troubleshooting.md#reporting-a-bug) says what's in them and how to blank out
character names.

## Changing code

Read [docs/development.md](docs/development.md) first, especially the rules for hidden values and
combat lockdown. Before opening a pull request:

```sh
luacheck ForeverDruid && luacheck tests   # separately: see .luacheckrc
lua tests/run.lua
```

Both must pass. New features need a test scenario, including the case where the client hides what
the feature needs. Keep pull requests to one change, and describe what a player will notice.

## Translations

Add or correct strings in `ForeverDruid/Locale.lua`. English strings are the keys; anything
untranslated falls back to English. Spell and item names never need translating: they come from
the client in the player's language.

## Licence

By contributing you agree that your contribution is licensed under the [Apache License 2.0](LICENSE),
the same as the rest of the project.
