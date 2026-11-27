#!/usr/bin/env bash
# Downloads the SwiftLint and SwiftFormat releases pinned in scripts/lint-swift.sh into a
# per-user cache keyed by version (default ~/Library/Caches/swift-quality-tools), so every
# clone, worktree and app shares one download. scripts/lint-swift.sh finds the cache on its
# own and calls this script when a pinned tool is missing; run it directly to install ahead
# of time (CI, Xcode Cloud ci_post_clone.sh, offline work).
#
# Usage: scripts/install-swift-tools.sh [--print-paths] [swiftlint] [swiftformat]
#   With no tool names both are installed. --print-paths writes only the cache directories
#   holding the binaries to stdout (one per line, ready for $GITHUB_PATH).
# SWIFT_QUALITY_TOOLS_CACHE overrides the cache directory.
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly GATE="$ROOT/scripts/lint-swift.sh"
readonly CACHE="${SWIFT_QUALITY_TOOLS_CACHE:-${XDG_CACHE_HOME:-$HOME/Library/Caches}/swift-quality-tools}"

usage() { echo "Usage: scripts/install-swift-tools.sh [--print-paths] [swiftlint] [swiftformat]" >&2; }

print_paths=false
tools=()
for arg in "$@"; do
  case "$arg" in
    --print-paths) print_paths=true ;;
    swiftlint|swiftformat) tools+=("$arg") ;;
    *) usage; exit 2 ;;
  esac
done
[[ "${#tools[@]}" -gt 0 ]] || tools=(swiftlint swiftformat)

pinned() {
  local value
  value="$(sed -n "s/^readonly $1=\"\(.*\)\"\$/\1/p" "$GATE")"
  [[ -n "$value" ]] || {
    echo "Could not read $1 from $GATE." >&2
    exit 1
  }
  printf '%s\n' "$value"
}

tool_version() {
  case "$1" in
    swiftlint) "$2" version ;;
    swiftformat) "$2" --version ;;
  esac 2>/dev/null || true
}

# Verifies the zip against the pinned SHA-256 before anything in it runs, and renames the
# binary into place inside the cache, so concurrent builds never see a partial file.
install_tool() {
  local name="$1" prefix version sha256 url dest actual
  prefix="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
  version="$(pinned "${prefix}_VERSION")"
  sha256="$(pinned "${prefix}_SHA256")"
  url="$(pinned "${prefix}_URL")"
  url="${url//\$${prefix}_VERSION/$version}"
  dest="$CACHE/$name-$version"

  if [[ -x "$dest/$name" && "$(tool_version "$name" "$dest/$name")" == "$version" ]]; then
    echo "$name $version is already installed in $dest" >&2
    [[ "$print_paths" == false ]] || printf '%s\n' "$dest"
    return 0
  fi

  mkdir -p "$dest"
  stage="$(mktemp -d "$CACHE/.$name-$version.XXXXXX")"

  curl --fail --location --silent --show-error "$url" --output "$stage/$name.zip"
  actual="$(shasum -a 256 "$stage/$name.zip" | awk '{print $1}')"
  [[ "$actual" == "$sha256" ]] || {
    echo "Checksum mismatch for $url: expected $sha256, got $actual." >&2
    return 1
  }
  unzip -q "$stage/$name.zip" "$name" -d "$stage/out"
  chmod +x "$stage/out/$name"
  [[ "$(tool_version "$name" "$stage/out/$name")" == "$version" ]] || {
    echo "Downloaded $name does not report $version." >&2
    return 1
  }
  mv -f "$stage/out/$name" "$dest/$name"
  rm -rf "$stage"

  echo "Installed $name $version in $dest" >&2
  [[ "$print_paths" == false ]] || printf '%s\n' "$dest"
}

# The staging directory sits in the cache so the final rename stays on one file system.
stage=""
trap 'rm -rf "${stage:-}"' EXIT INT TERM

mkdir -p "$CACHE"
for tool in "${tools[@]}"; do
  install_tool "$tool"
done
