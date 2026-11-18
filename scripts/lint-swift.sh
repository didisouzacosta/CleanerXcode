#!/usr/bin/env bash
set -euo pipefail

readonly SWIFTLINT_VERSION="0.63.2"
readonly SWIFTFORMAT_VERSION="0.63.0"
# The release zips scripts/install-swift-tools.sh downloads, and their SHA-256; update them
# together with the versions.
readonly SWIFTLINT_URL="https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip"
readonly SWIFTLINT_SHA256="c59a405c85f95b92ced677a500804e081596a4cae4a6a485af76065557d6ed29"
readonly SWIFTFORMAT_URL="https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/swiftformat.zip"
readonly SWIFTFORMAT_SHA256="28c7802e11fa5ae113d903066439c6bb1be20a8ac1ad9709c42616a7e273fb0f"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TOOLS_CACHE="${SWIFT_QUALITY_TOOLS_CACHE:-${XDG_CACHE_HOME:-$HOME/Library/Caches}/swift-quality-tools}"
cd "$ROOT"

# Xcode build phases and CI do not inherit the interactive PATH: look in the caller's PATH,
# then Homebrew; .build/quality-tools/bin is where older installers put the pinned tools.
export PATH="$ROOT/.build/quality-tools/bin:$PATH:/opt/homebrew/bin:/usr/local/bin"

mode=lint
case "${1:-}" in
  "") ;;
  --fix) mode=fix ;;
  --format-only) mode=format-only ;;
  --add-marks) mode=add-marks ;;
  *) echo "Usage: scripts/lint-swift.sh [--fix | --format-only | --add-marks]" >&2; exit 2 ;;
esac

swift_paths=()
swift_path_count=0
submodule_paths=()
submodule_count=0

if [[ -f .gitmodules ]]; then
  while IFS= read -r line; do
    submodule_paths+=("${line#* }")
    submodule_count=$((submodule_count + 1))
  done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
fi

add_file() {
  local path="$1" existing submodule normalized="${1#./}"
  [[ -f "$path" && ! -L "$path" ]] || return 0
  if [[ "$submodule_count" -gt 0 ]]; then
    for submodule in "${submodule_paths[@]}"; do
      [[ "$normalized" != "$submodule" && "$normalized" != "$submodule/"* ]] || return 0
    done
  fi
  swift_path_count=$((swift_path_count + 1))
  if [[ "$swift_path_count" -gt 1 ]]; then
    for existing in "${swift_paths[@]}"; do
      if [[ "$existing" == "$path" ]]; then
        swift_path_count=$((swift_path_count - 1))
        return 0
      fi
    done
  fi
  swift_paths+=("$path")
}

add_swift_tree() {
  local tree="$1" path absolute_tree submodule normalized_tree="${1#./}"
  [[ -d "$tree" && ! -L "$tree" ]] || return 0
  absolute_tree="$ROOT/${tree#./}"
  if [[ "$submodule_count" -gt 0 ]]; then
    for submodule in "${submodule_paths[@]}"; do
      [[ "$normalized_tree" != "$submodule" && "$normalized_tree" != "$submodule/"* ]] || return 0
    done
  fi
  local -a find_args=("$absolute_tree")
  if [[ "$submodule_count" -gt 0 ]]; then
    for submodule in "${submodule_paths[@]}"; do
      find_args+=( -path "$ROOT/$submodule" -prune -o )
    done
  fi
  while IFS= read -r -d '' path; do
    add_file "${path#"$ROOT/"}"
  done < <(
    find "${find_args[@]}" \
      \( -type d \( -name .git -o -name .ai -o -name .build -o -name .swiftpm \
        -o -name .cache -o -name DerivedData \) -prune \) -o \
      \( -type f -name '*.swift' -print0 \)
  )
}

# SwiftPM and conventional project-root layouts.
add_swift_tree Sources
add_swift_tree Tests
add_file Package.swift

# Xcode projects commonly keep synchronized Sources/Tests roots inside the app.
while IFS= read -r -d '' app_root; do
  add_swift_tree "$app_root/Sources"
  add_swift_tree "$app_root/Tests"
done < <(
  find . -mindepth 1 -maxdepth 1 -type d \
    ! -name '.*' ! -name Packages -print0
)

if [[ -d Packages && ! -L Packages ]]; then
  while IFS= read -r -d '' package; do
    case "$(basename "$package")" in
      .ai|.build|.swiftpm|.cache|DerivedData|.git) continue ;;
    esac
    add_swift_tree "$package/Sources"
    add_swift_tree "$package/Tests"
    add_file "$package/Package.swift"
  done < <(find Packages -mindepth 1 -maxdepth 1 -type d -print0)
fi

if [[ "$swift_path_count" -eq 0 ]]; then
  echo "No Swift sources, tests, or Package.swift files found in supported project paths." >&2
  exit 1
fi

readonly INSTALL_HINT="check the network and run scripts/install-swift-tools.sh, or brew install swiftlint swiftformat"

tool_version() {
  case "$1" in
    swiftlint) "$2" version ;;
    swiftformat) "$2" --version ;;
  esac 2>/dev/null || true
}

# Prints the first binary named $1 that reports the pinned version $2: from PATH, then the
# per-user cache. When none does, it installs that version into the cache, unless
# SWIFT_QUALITY_TOOLS_AUTO_INSTALL=0. A different version found on the way is skipped, so a
# newer Homebrew release never breaks the gate.
resolve_tool() {
  local name="$1" version="$2" dir candidate
  local -a dirs
  IFS=: read -r -a dirs <<< "$PATH"
  for dir in "${dirs[@]}" "$TOOLS_CACHE/$name-$version"; do
    candidate="$dir/$name"
    [[ -n "$dir" && -f "$candidate" && -x "$candidate" ]] || continue
    if [[ "$(tool_version "$name" "$candidate")" == "$version" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  [[ "${SWIFT_QUALITY_TOOLS_AUTO_INSTALL:-1}" != 0 ]] || return 1
  echo "Installing $name $version in $TOOLS_CACHE..." >&2
  SWIFT_QUALITY_TOOLS_CACHE="$TOOLS_CACHE" bash "$ROOT/scripts/install-swift-tools.sh" "$name" >&2 || return 1
  candidate="$TOOLS_CACHE/$name-$version/$name"
  [[ "$(tool_version "$name" "$candidate")" == "$version" ]] || return 1
  printf '%s\n' "$candidate"
}

swiftformat="$(resolve_tool swiftformat "$SWIFTFORMAT_VERSION")" || {
  echo "SwiftFormat $SWIFTFORMAT_VERSION is required; $INSTALL_HINT." >&2
  exit 1
}

if [[ "$mode" == format-only ]]; then
  # Non-mutating layout check for Xcode build phases; SwiftLint runs as the build plugin.
  "$swiftformat" --lint --quiet --config .swiftformat "${swift_paths[@]}"
  exit 0
fi

swiftlint="$(resolve_tool swiftlint "$SWIFTLINT_VERSION")" || {
  echo "SwiftLint $SWIFTLINT_VERSION is required; $INSTALL_HINT." >&2
  exit 1
}
command -v perl >/dev/null 2>&1 || {
  echo "perl is required by scripts/fix-swift-spacing.pl." >&2
  exit 1
}

if [[ "$mode" == add-marks ]]; then
  # Drafts the required type MARK sections; review the generated names before committing.
  command -v python3 >/dev/null 2>&1 || { echo "python3 is required by scripts/add-type-marks.py." >&2; exit 1; }
  python3 scripts/add-type-marks.py "${swift_paths[@]}"
  exit 0
fi

if [[ "$mode" == fix ]]; then
  # SwiftFormat owns layout; the spacing fixer inserts the blank lines SwiftFormat cannot
  # express; SwiftLint applies its correctable rules; a final SwiftFormat pass stabilizes.
  echo "Formatting Swift files at paths ${swift_paths[*]}"
  "$swiftformat" --quiet --config .swiftformat "${swift_paths[@]}"
  perl scripts/fix-swift-spacing.pl "${swift_paths[@]}"
  "$swiftlint" lint --fix --quiet --no-cache --config .swiftlint.yml "${swift_paths[@]}"
  "$swiftformat" --quiet --config .swiftformat "${swift_paths[@]}"
  perl scripts/fix-swift-spacing.pl "${swift_paths[@]}"
  echo "Missing type MARK sections are not fixed here; scripts/lint-swift.sh --add-marks drafts them for review."
fi

echo "Linting Swift files at paths ${swift_paths[*]}"
"$swiftformat" --lint --config .swiftformat "${swift_paths[@]}"
"$swiftlint" lint --strict --no-cache --config .swiftlint.yml "${swift_paths[@]}"
