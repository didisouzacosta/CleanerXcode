#!/usr/bin/env bash
# Imports the Developer ID Application certificate into a temporary keychain for codesign
# (C42) and prints the keychain path. Delete it with `security delete-keychain` when done.
#
# Reads: DEVELOPER_ID_CERTIFICATE_P12_BASE64, DEVELOPER_ID_CERTIFICATE_PASSWORD, RUNNER_TEMP
set -euo pipefail

: "${DEVELOPER_ID_CERTIFICATE_P12_BASE64:?missing secret DEVELOPER_ID_CERTIFICATE_P12_BASE64}"
: "${DEVELOPER_ID_CERTIFICATE_PASSWORD:?missing secret DEVELOPER_ID_CERTIFICATE_PASSWORD}"

readonly WORK="${RUNNER_TEMP:-$(mktemp -d)}"
readonly KEYCHAIN="$WORK/release-signing.keychain-db"
readonly CERTIFICATE="$WORK/developer-id.p12"
readonly KEYCHAIN_PASSWORD="$(uuidgen)"

umask 077
printf '%s' "$DEVELOPER_ID_CERTIFICATE_P12_BASE64" | base64 --decode > "$CERTIFICATE"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERTIFICATE" -k "$KEYCHAIN" -P "$DEVELOPER_ID_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
rm -f "$CERTIFICATE"

if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "Developer ID Application"; then
  echo "The certificate is not a Developer ID Application identity." >&2
  exit 1
fi

echo "$KEYCHAIN"
