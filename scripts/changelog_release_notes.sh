#!/usr/bin/env bash
set -euo pipefail

# Build GitHub Release notes from the active changelog draft.
#
# Usage: scripts/changelog_release_notes.sh <version> [out_file]
#
# The <version> is decided by the release admin (CI bump / chosen tag), NOT by
# the changelog. The changelog draft only carries the bullets; its title is a
# placeholder (# 1.2.x — …) and is ignored for numbering.
#
# This script:
#   - takes the exact shipped <version> from the admin (e.g. 1.2.165),
#   - resolves the codename from kReleaseCodename in app_version.dart (source of
#     truth for the shipping minor),
#   - maps 1.2.165 -> docs/changelog/1.2.x-[draft].md for the body bullets,
#   - drops empty thematic groups + editor scaffolding.
#
# Output is used as the GitHub Release body, which the in-app update dialog shows
# verbatim (AppUpdaterService reads release `body`). Prints to stdout and, when
# out_file is given, writes it there too. Exits 0 with no group sections when the
# draft is missing or empty (CI falls back to generate_release_notes).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: changelog_release_notes.sh <version> [out_file]}"
OUT="${2:-}"

IFS=. read -r major minor _patch <<<"$VERSION"
draft="$ROOT/docs/changelog/${major}.${minor}.x-[draft].md"

# Codename source of truth: kReleaseCodename in app_version.dart (admin updates
# it when shipping a new minor). Not read from the changelog title.
version_dart="$ROOT/apps/forja/lib/shared/services/app_version.dart"
codename=""
if [[ -f "$version_dart" ]]; then
  codename="$(sed -n "s/^const kReleaseCodename = '\(.*\)';/\1/p" "$version_dart" | head -1)"
fi

lines=()

if [[ -n "$codename" ]]; then
  lines+=("# ${VERSION} — ${codename}" "")
else
  lines+=("# ${VERSION}" "")
fi

if [[ ! -f "$draft" ]]; then
  echo "::warning::No changelog draft at docs/changelog/${major}.${minor}.x-[draft].md" >&2
else
  header=""
  buffer=()

  flush() {
    if [[ -n "$header" && ${#buffer[@]} -gt 0 ]]; then
      lines+=("$header")
      for b in "${buffer[@]}"; do lines+=("$b"); done
      lines+=("")
    fi
    header=""
    buffer=()
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      '### '*) flush; header="$line" ;;
      '- '*|'* '*) [[ -n "$header" ]] && buffer+=("$line") ;;
      *) : ;;
    esac
  done <"$draft"
  flush
fi

body="$(printf '%s\n' "${lines[@]}")"

if [[ -n "$OUT" ]]; then
  printf '%s\n' "$body" >"$OUT"
fi
printf '%s\n' "$body"
