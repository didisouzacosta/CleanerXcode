#!/usr/bin/env bash
# Uploads the dSYMs of a Release archive to Sentry (project cleanerxcode-macos in godolabs, read
# from .sentryclirc), so crash reports from the distributed app have readable stack traces. Run
# it for every archive you distribute, after `xcodebuild archive` (D9).
#
# Usage: scripts/upload-dsyms.sh <path to .xcarchive or a folder of dSYMs>
# Needs sentry-cli (`brew install getsentry/tools/sentry-cli`) and an auth token with the
# project:releases scope: run `sentry-cli login` once, or export SENTRY_AUTH_TOKEN. The token
# never goes into the repository.
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -ne 1 ]; then
  echo "Usage: scripts/upload-dsyms.sh <path to .xcarchive or a folder of dSYMs>" >&2
  exit 2
fi

if ! command -v sentry-cli >/dev/null 2>&1; then
  echo "sentry-cli not found: brew install getsentry/tools/sentry-cli" >&2
  exit 1
fi

source_path="$1"
[ -d "$source_path/dSYMs" ] && source_path="$source_path/dSYMs"

if [ ! -d "$source_path" ]; then
  echo "No such folder: $source_path" >&2
  exit 1
fi

cd "$ROOT"
sentry-cli debug-files check "$source_path" >/dev/null 2>&1 || true
sentry-cli debug-files upload --include-sources "$source_path"
