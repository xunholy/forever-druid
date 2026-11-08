# Publishing

Releases are cut by pushing a version tag. Locally, `scripts/deploy.sh` installs the addon into
the game and `scripts/package.sh` builds the zip.

## 1. The repository

The code lives at https://github.com/xunholy/forever-druid. CI (`.github/workflows/ci.yml`) lints
and tests every push and pull request that touches the addon.

## 2. Cut a release

1. Bump `## Version` in `ForeverDruid/ForeverDruid.toc`, add a `CHANGELOG.md` entry and a
   player-facing entry at the top of `ns.RELEASE_NOTES` in `ForeverDruid/Onboarding.lua`
   (that's the in-game "What's new").
2. Tag and push: `git tag v0.5.0 && git push origin v0.5.0`.
3. `.github/workflows/release.yml` lints, tests, and uses the BigWigs packager to build
   `ForeverDruid-v0.5.0.zip` and attach it to a GitHub release.

## 3. CurseForge and Wago (optional)

1. Create the project at https://authors.curseforge.com (game: World of Warcraft) and/or on Wago
   Addons, named "Forever Druid" (text for the page is in `listing.md`). New CurseForge projects are reviewed by moderators before they go public.
2. Add the IDs to the TOC: `## X-Curse-Project-ID: <id>` and `## X-Wago-ID: <id>`.
3. Add repository secrets `CF_API_TOKEN` (authors.curseforge.com > settings > API tokens) and
   `WAGO_API_TOKEN` (addons.wago.io > account > API keys), e.g. `gh secret set CF_API_TOKEN`.
4. The next tag uploads there too, so players with the CurseForge app get updates automatically.
   The packager reads `## Interface: 16001` as Forever and tags the file for game version 1.60.1;
   the CurseForge changelog comes from `CHANGELOG.md`.

Check a build without uploading: download the packager's `release.sh` and run
`bash release.sh -d -r /tmp/fd-release` in the repository.

## Project icon

`docs/icon.png` (512×512) is the CurseForge / Wago project avatar; `docs/icon.svg` is its source.
Re-render after editing the SVG, e.g. with headless Chrome:
`google-chrome --headless=new --default-background-color=00000000 --window-size=512,512 --screenshot=docs/icon.png docs/icon.svg`.

## Screenshots

Take them with the HUD unlocked (sample icons fill every row), on a neutral character and
location, with chat and personal UI hidden. Don't publish screenshots of your own account,
guild or friends list.
