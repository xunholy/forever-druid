#!/usr/bin/env bash
# Run the tests, then copy ForeverDruid into the WoW Forever AddOns folder.
# Override the destination with FOREVER_ADDONS=/path/to/_forever_/Interface/AddOns.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
addons="${FOREVER_ADDONS:-/mnt/d/Battle.net/World of Warcraft/_forever_/Interface/AddOns}"

cd "$repo"
for f in ForeverDruid/*.lua ForeverDruid/Modules/*.lua; do
	luac -p "$f"
done
lua tests/run.lua >/dev/null || { lua tests/run.lua | grep -E 'FAIL'; exit 1; }

if [ ! -d "$addons" ]; then
	echo "AddOns folder not found: $addons" >&2
	exit 1
fi

rsync -a --delete "$repo/ForeverDruid/" "$addons/ForeverDruid/"
echo "Deployed ForeverDruid $(grep -m1 '^## Version' ForeverDruid/ForeverDruid.toc | cut -d' ' -f3) to $addons/ForeverDruid"
echo "In game: /reload (or restart the client if this is the first install)."
