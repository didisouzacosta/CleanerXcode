#!/usr/bin/env bash
# Re-signs Sparkle's helpers with the Developer ID and the hardened runtime, then the app
# (C42), as Sparkle documents for apps signed outside Xcode's export. CleanerXcode is not
# sandboxed, so Sparkle's XPC services are not needed and are removed first.
#
# Usage: scripts/release/sign-sparkle.sh <CleanerXcode.app> <signing identity> <keychain>
set -euo pipefail

readonly APP="$1"
readonly IDENTITY="$2"
readonly KEYCHAIN="$3"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ENTITLEMENTS="$ROOT/CleanerXcode/CleanerXcode.entitlements"
readonly SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"

sign() {
  codesign --force --timestamp --options runtime --keychain "$KEYCHAIN" --sign "$IDENTITY" "$@"
}

if [ ! -d "$SPARKLE" ]; then
  echo "Sparkle.framework not found in $APP" >&2
  exit 1
fi

rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/XPCServices"

sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
sign --entitlements "$ENTITLEMENTS" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
