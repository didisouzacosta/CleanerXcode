#!/usr/bin/env bash
# Saves the release secrets and the Sparkle public key in this repository's GitHub settings
# (C42). Run it yourself, in a terminal: it asks for each value, reads files and the keychain,
# and pipes everything straight into `gh secret set`, so nothing is printed or saved in the
# repository. Secrets that already exist are kept unless you choose to replace them.
#
# Usage: scripts/release/setup-github-secrets.sh
# Needs: gh (logged in with access to the repository), asc for the Developer ID path that starts
# from a CSR, and Xcode to fetch Sparkle's tools. Private files it creates go to
# ~/.cleanerxcode-release (mode 700); delete that folder once the secrets are saved.
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly PRIVATE_DIR="$HOME/.cleanerxcode-release"
readonly R2_ACCOUNT_ID_DEFAULT="9b6e152fa365d3382f3b97e283af3c27"
# A key pair only for CleanerXcode, apart from any other app's Sparkle keys.
readonly SPARKLE_ACCOUNT="cleanerxcode"

umask 077
mkdir -p "$PRIVATE_DIR"
chmod 700 "$PRIVATE_DIR"
cd "$ROOT"

existing_secrets="$(gh secret list --json name --jq '.[].name')"

title() { printf '\n== %s ==\n' "$1"; }

has_secret() { grep -qx "$1" <<< "$existing_secrets"; }

# Asks whether to (re)write a secret that already exists.
should_write() {
  local name="$1" answer
  has_secret "$name" || return 0
  read -r -p "$name already exists. Replace it? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# Reads a value without echoing it and saves it as a secret.
secret_from_prompt() {
  local name="$1" prompt="$2" value
  should_write "$name" || { echo "Kept $name."; return; }
  read -r -s -p "$prompt: " value
  echo
  [ -n "$value" ] || { echo "Empty: skipped $name."; return; }
  printf '%s' "$value" | gh secret set "$name"
  unset value
  echo "Saved $name."
}

secret_from_file() {
  local name="$1" file="$2"
  should_write "$name" || { echo "Kept $name."; return; }
  gh secret set "$name" < "$file"
  echo "Saved $name."
}

sparkle_tool() {
  local tool="$1" found
  found="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/CleanerXcode-*/SourcePackages/artifacts/sparkle/Sparkle/bin/"$tool" 2>/dev/null | head -n 1 || true)"

  if [ -z "$found" ]; then
    echo "Fetching the Sparkle package (SwiftPM checks its checksum)..." >&2
    xcodebuild -resolvePackageDependencies -project CleanerXcode.xcodeproj -scheme CleanerXcode \
      -derivedDataPath "$PRIVATE_DIR/DerivedData" >/dev/null
    found="$PRIVATE_DIR/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/$tool"
  fi

  [ -x "$found" ] || { echo "Sparkle's $tool not found." >&2; exit 1; }
  printf '%s\n' "$found"
}

title "Sparkle update keys"
generate_keys="$(sparkle_tool generate_keys)"
echo "generate_keys keeps the key pair in your login keychain (macOS may ask to allow it)."
"$generate_keys" --account "$SPARKLE_ACCOUNT" >/dev/null
public_key="$("$generate_keys" --account "$SPARKLE_ACCOUNT" -p)"
gh variable set SPARKLE_PUBLIC_ED_KEY --body "$public_key"
echo "Saved the variable SPARKLE_PUBLIC_ED_KEY: $public_key"

if should_write SPARKLE_ED_PRIVATE_KEY; then
  exported="$PRIVATE_DIR/sparkle-private-key.txt"
  rm -f "$exported"
  "$generate_keys" --account "$SPARKLE_ACCOUNT" -x "$exported" >/dev/null
  gh secret set SPARKLE_ED_PRIVATE_KEY < "$exported"
  rm -f "$exported"
  echo "Saved SPARKLE_ED_PRIVATE_KEY. Back up the key pair from Keychain Access (\"Private key for signing Sparkle updates\")."
else
  echo "Kept SPARKLE_ED_PRIVATE_KEY."
fi

title "Developer ID certificate"
if should_write DEVELOPER_ID_CERTIFICATE_P12_BASE64; then
  echo "1) I already have a .p12 of \"Developer ID Application\" (export it from Keychain Access on the Mac that has it)"
  echo "2) Create a new one: this script makes the CSR, you upload it at developer.apple.com (Account Holder)"
  read -r -p "Choose 1 or 2: " choice

  password_file="$PRIVATE_DIR/developer-id.p12.password"
  p12="$PRIVATE_DIR/developer-id.p12"

  if [ "$choice" = "2" ]; then
    key="$PRIVATE_DIR/developer-id.key"
    csr="$PRIVATE_DIR/developer-id.csr"
    [ -e "$key" ] || openssl req -new -newkey rsa:2048 -nodes -keyout "$key" -out "$csr" \
      -subj "/CN=Adriano Souza Costa/O=Adriano Souza Costa/C=BR" 2>/dev/null
    echo "CSR: $csr"
    echo "Open https://developer.apple.com/account/resources/certificates/add, choose Developer ID Application,"
    echo "the G2 Sub-CA, upload the CSR and download the .cer."
    read -r -p "Path of the downloaded .cer: " cer
    openssl rand -base64 32 > "$password_file"
    asc certificates export --certificate "$cer" --private-key "$key" --csr "$csr" \
      --password-file "$password_file" --p12-out "$p12" --force --confirm >/dev/null
  else
    read -r -p "Path of the .p12: " source_p12
    cp "$source_p12" "$p12"
    read -r -s -p "Its password: " p12_password
    echo
    printf '%s' "$p12_password" > "$password_file"
    unset p12_password
  fi

  base64 -i "$p12" | tr -d '\n' | gh secret set DEVELOPER_ID_CERTIFICATE_P12_BASE64
  gh secret set DEVELOPER_ID_CERTIFICATE_PASSWORD < "$password_file"
  echo "Saved DEVELOPER_ID_CERTIFICATE_P12_BASE64 and DEVELOPER_ID_CERTIFICATE_PASSWORD."
else
  echo "Kept DEVELOPER_ID_CERTIFICATE_P12_BASE64."
  has_secret DEVELOPER_ID_CERTIFICATE_PASSWORD \
    || secret_from_prompt DEVELOPER_ID_CERTIFICATE_PASSWORD "Password of the .p12 already saved"
fi

title "App Store Connect API key (notarization)"
echo "Create one at https://appstoreconnect.apple.com/access/integrations/api (role Developer)."
secret_from_prompt APPLE_API_KEY_ID "Key ID"
secret_from_prompt APPLE_API_ISSUER_ID "Issuer ID"
if should_write APPLE_API_PRIVATE_KEY; then
  read -r -p "Path of AuthKey_<ID>.p8: " p8
  gh secret set APPLE_API_PRIVATE_KEY < "$p8"
  echo "Saved APPLE_API_PRIVATE_KEY."
else
  echo "Kept APPLE_API_PRIVATE_KEY."
fi

title "Cloudflare R2"
echo "Create a token at R2 > Manage API tokens: Object Read & Write, only the bucket cleanerxcode-downloads."
if should_write R2_ACCOUNT_ID; then
  printf '%s' "$R2_ACCOUNT_ID_DEFAULT" | gh secret set R2_ACCOUNT_ID
  echo "Saved R2_ACCOUNT_ID."
fi
secret_from_prompt R2_ACCESS_KEY_ID "Access Key ID"
secret_from_prompt R2_SECRET_ACCESS_KEY "Secret Access Key"

title "Analytics and crash reports (optional, Enter skips)"
secrets_file="$ROOT/CleanerXcode/Secrets.xcconfig"
for name in HIMETRICA_API_KEY SENTRY_DSN; do
  value="$(sed -n "s/^$name = //p" "$secrets_file" 2>/dev/null | sed 's#/$()/#//#g' || true)"
  if [ -n "$value" ] && should_write "$name"; then
    printf '%s' "$value" | gh secret set "$name"
    echo "Saved $name from CleanerXcode/Secrets.xcconfig."
  elif [ -z "$value" ]; then
    secret_from_prompt "$name" "$name"
  fi
  unset value
done
secret_from_prompt SENTRY_AUTH_TOKEN "Sentry auth token (project:releases)"

title "Push token (optional)"
echo "Only if a rule on main blocks pushes from GITHUB_TOKEN (see docs/RELEASE.md)."
secret_from_prompt RELEASE_PUSH_TOKEN "Fine-grained token with Contents: Read and write"

title "Done"
gh secret list
gh variable list
echo "Delete $PRIVATE_DIR once you have backed up what you need."
