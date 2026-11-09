#!/usr/bin/env bash
# Builds the installer disk image (C42): the app and a link to /Applications, compressed.
#
# Usage: scripts/release/make-dmg.sh <CleanerXcode.app> <output.dmg>
set -euo pipefail

readonly APP="$1"
readonly OUTPUT="$2"
readonly STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "CleanerXcode" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUTPUT" >/dev/null

echo "Created $OUTPUT"
