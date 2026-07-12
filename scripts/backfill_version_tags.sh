#!/usr/bin/env bash
set -euo pipefail

# Tag every commit on the current branch since the latest v* tag (one patch bump per
# untagged commit, oldest first). Used by .github/workflows/backfill-tags.yml.
#
# Usage:
#   ./scripts/backfill_version_tags.sh          # create and push tags
#   ./scripts/backfill_version_tags.sh --dry-run

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

cd "$ROOT"
git fetch origin --tags --force 2>/dev/null || true

latest="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)"
if [[ -n "$latest" ]]; then
  base_semver="${latest#v}"
  range="${latest}..HEAD"
else
  base_semver="$(grep '^version:' apps/forja/pubspec.yaml | sed 's/version: *//' | cut -d+ -f1)"
  range="HEAD"
fi

IFS=. read -r major minor patch <<<"$base_semver"
made=0

for sha in $(git rev-list --reverse "$range"); do
  if git tag --points-at "$sha" | grep -q '^v[0-9]'; then
    continue
  fi
  patch=$((patch + 1))
  tag="v${major}.${minor}.${patch}"
  while git rev-parse "$tag" >/dev/null 2>&1; do
    patch=$((patch + 1))
    tag="v${major}.${minor}.${patch}"
  done
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Would tag $tag -> $sha"
  else
    git tag -a "$tag" -m "Forja ${major}.${minor}.${patch}" "$sha"
    echo "Tagged $tag -> $sha"
  fi
  made=$((made + 1))
done

if [[ "$made" -eq 0 ]]; then
  echo "No untagged commits to backfill."
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run: $made tag(s) would be created."
else
  git push origin --tags
  echo "Pushed $made tag(s)."
fi
