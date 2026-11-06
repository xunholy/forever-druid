# Publishing

Nothing here runs until you choose to publish. Today the addon is installed by
`scripts/deploy.sh` and packaged locally by `scripts/package.sh`.

## 1. Put the repository on GitHub

Create an empty repository, add it as `origin` and push `main`. CI (`.github/workflows/ci.yml`)
then lints and tests every push and pull request that touches the addon.

## 2. Cut a release

1. Bump `## Version` in `ForeverDruid/ForeverDruid.toc`, add a `CHANGELOG.md` entry and a
   player-facing entry at the top of `ns.RELEASE_NOTES` in `ForeverDruid/Onboarding.lua`
   (that's the in-game "What's new").
2. Tag and push: `git tag v0.5.0 && git push origin v0.5.0`.
3. `.github/workflows/release.yml` lints, tests, and uses the BigWigs packager to build
   `ForeverDruid-v0.5.0.zip` and attach it to a GitHub release.

## 3. CurseForge and Wago (optional)

1. Create the project on CurseForge (game: World of Warcraft, flavour: Forever) and/or Wago Addons.
2. Add the IDs to the TOC: `## X-Curse-Project-ID: <id>` and `## X-Wago-ID: <id>`.
3. Add repository secrets `CF_API_KEY` (CurseForge > API tokens) and `WAGO_API_TOKEN`.
4. The next tag uploads there too, so players with the CurseForge app get updates automatically.

## Screenshots

Take them with the HUD unlocked (sample icons fill every row), on a neutral character and
location, with chat and personal UI hidden. Don't publish screenshots of your own account,
guild or friends list.
