#!/usr/bin/env bash
# Build a release zip (dist/ForeverDruid-<version>.zip) after the tests pass.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

for f in ForeverDruid/*.lua ForeverDruid/Modules/*.lua; do
	luac -p "$f"
done
lua tests/run.lua >/dev/null || { lua tests/run.lua | grep -E 'FAIL'; exit 1; }

version="$(grep -m1 '^## Version' ForeverDruid/ForeverDruid.toc | cut -d' ' -f3 | tr -d '\r')"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

cp -r ForeverDruid "$stage/ForeverDruid"
cp LICENSE NOTICE CHANGELOG.md "$stage/ForeverDruid/"
mkdir -p dist
rm -f "dist/ForeverDruid-$version.zip"
(cd "$stage" && zip -qr "$repo/dist/ForeverDruid-$version.zip" ForeverDruid)
echo "Built dist/ForeverDruid-$version.zip"
