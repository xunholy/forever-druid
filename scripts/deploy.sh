#!/usr/bin/env bash
# Run the tests, then copy ForeverDruid into the WoW Forever AddOns folder.
# Set FOREVER_ADDONS to your WoW Forever AddOns folder, for example
#   FOREVER_ADDONS="/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns" scripts/deploy.sh
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
addons="${FOREVER_ADDONS:?set FOREVER_ADDONS to your _forever_/Interface/AddOns folder}"

cd "$repo"
for f in ForeverDruid/*.lua ForeverDruid/Modules/*.lua; do
	luac -p "$f"
done
if command -v luacheck >/dev/null; then
	luacheck . --quiet
else
	echo "luacheck not installed; skipping lint" >&2
fi
lua tests/run.lua >/dev/null || { lua tests/run.lua | grep -E 'FAIL'; exit 1; }

if [ ! -d "$addons" ]; then
	echo "AddOns folder not found: $addons" >&2
	exit 1
fi

rsync -a --delete "$repo/ForeverDruid/" "$addons/ForeverDruid/"
echo "Deployed ForeverDruid $(grep -m1 '^## Version' ForeverDruid/ForeverDruid.toc | cut -d' ' -f3) to $addons/ForeverDruid"
echo "In game: /reload (or restart the client if this is the first install)."
