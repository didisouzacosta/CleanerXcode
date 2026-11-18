#!/usr/bin/env bash
# Sends a .zip, .dmg or .pkg to Apple's notary service and waits (C42). On any status other
# than Accepted it prints the notary log and fails. Staple the result yourself.
#
# Usage: scripts/release/notarize.sh <file>
# Reads: APPLE_API_KEY_ID, APPLE_API_ISSUER_ID, APPLE_API_PRIVATE_KEY (the .p8 contents)
set -euo pipefail

: "${APPLE_API_KEY_ID:?missing secret APPLE_API_KEY_ID}"
: "${APPLE_API_ISSUER_ID:?missing secret APPLE_API_ISSUER_ID}"
: "${APPLE_API_PRIVATE_KEY:?missing secret APPLE_API_PRIVATE_KEY}"

readonly FILE="$1"
readonly WORK="$(mktemp -d)"
readonly KEY="$WORK/AuthKey_$APPLE_API_KEY_ID.p8"
trap 'rm -rf "$WORK"' EXIT

umask 077
printf '%s\n' "$APPLE_API_PRIVATE_KEY" > "$KEY"

credentials=(--key "$KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")

# A failed submit still prints JSON with the submission id: read it before deciding.
result="$(xcrun notarytool submit "$FILE" "${credentials[@]}" --wait --timeout 45m --output-format json || true)"
field() {
  printf '%s' "$result" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get(sys.argv[1], ""))
except ValueError:
    print("")' "$1"
}
status="$(field status)"
submission="$(field id)"

echo "Notarization of $(basename "$FILE"): $status ($submission)"

if [ "$status" != "Accepted" ]; then
  [ -n "$submission" ] && xcrun notarytool log "$submission" "${credentials[@]}" || true
  exit 1
fi
