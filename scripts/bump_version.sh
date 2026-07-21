#!/usr/bin/env bash
set -euo pipefail

# Bump apps/forja semver and increment build number.
# Default: patch (used by release.yml on manual dispatch).
# Updates installer/windows/setup.iss MyAppVersion.
# Prints new version to stdout (for CI: echo "version=$NEW" >> "$GITHUB_OUTPUT").

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUMP="${1:-patch}"

PUBSPEC="$ROOT/apps/forja/pubspec.yaml"
SETUP_ISS="$ROOT/installer/windows/setup.iss"

current="$(grep '^version:' "$PUBSPEC" | sed 's/version: *//')"
semver="${current%%+*}"
build="${current#*+}"
[[ "$build" == "$current" ]] && build=0

IFS=. read -r major minor patch <<<"$semver"

# Sync only with tags on the current minor arc (e.g. v1.2.*). Stale local tags
# from other minors (v1.3 / v1.4 leftovers) must not jump the bump.
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  latest_tag="$(git -C "$ROOT" tag -l "v${major}.${minor}.*" --sort=-v:refname 2>/dev/null | head -1 || true)"
  if [[ -n "$latest_tag" ]]; then
    tag_semver="${latest_tag#v}"
    semver="$(printf '%s\n%s\n' "$semver" "$tag_semver" | sort -V | tail -1)"
    IFS=. read -r major minor patch <<<"$semver"
  fi
fi

case "$BUMP" in
  patch) patch=$((patch + 1)) ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
  *) echo "invalid bump: $BUMP" >&2; exit 1 ;;
esac

build=$((build + 1))
new="${major}.${minor}.${patch}+${build}"

sed -i.bak "s/^version: .*/version: $new/" "$PUBSPEC"
rm -f "$PUBSPEC.bak"

semver_line="  #define MyAppVersion \"${major}.${minor}.${patch}\""
if [[ "$(uname -s)" == Darwin ]]; then
  sed -i '' "s/^  #define MyAppVersion \".*\"/${semver_line}/" "$SETUP_ISS"
else
  sed -i "s/^  #define MyAppVersion \".*\"/${semver_line}/" "$SETUP_ISS"
fi

echo "${major}.${minor}.${patch}"
