#!/usr/bin/env bash
set -euo pipefail

# Fail when apps/forja/pubspec.yaml semver differs from the release version.
# Flutter stamps the binary (Windows VERSIONINFO, macOS CFBundleShortVersionString,
# Android versionName) from pubspec. Packaging a tag whose commit never bumped
# pubspec ships an app that reports the old version — the updater then offers
# the same release forever.
#
# Usage:
#   check_pubspec_version.sh 2.0.11            # working tree
#   check_pubspec_version.sh 2.0.11 v2.0.11    # pubspec at a git ref

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED="${1:?usage: check_pubspec_version.sh <version> [git-ref]}"
EXPECTED="${EXPECTED#v}"
REF="${2:-}"
PUBSPEC_REL="apps/forja/pubspec.yaml"

if [[ -n "$REF" ]]; then
  content="$(git -C "$ROOT" show "${REF}:${PUBSPEC_REL}")"
  where="$PUBSPEC_REL at $REF"
else
  content="$(cat "$ROOT/$PUBSPEC_REL")"
  where="$PUBSPEC_REL"
fi

actual="$(printf '%s\n' "$content" | grep -m1 '^version:' | sed 's/version: *//')"
actual="${actual%%+*}"

if [[ "$actual" != "$EXPECTED" ]]; then
  echo "error: $where is $actual, release is $EXPECTED." >&2
  echo "The built app would report $actual and keep offering the $EXPECTED update." >&2
  echo "Release a commit that bumps pubspec (New version / bump_version.sh) instead of tagging an unbumped commit." >&2
  exit 1
fi

echo "ok: $where matches $EXPECTED"
