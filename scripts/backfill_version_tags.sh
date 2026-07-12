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

resolve_range() {
  local highest second untagged_between
  highest="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)"
  if [[ -z "$highest" ]]; then
    base_semver="$(grep '^version:' apps/forja/pubspec.yaml | sed 's/version: *//' | cut -d+ -f1)"
    range="HEAD"
    return
  fi

  second="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | sed -n '2p')"
  if [[ -n "$second" ]]; then
    local highest_sha
    highest_sha="$(git rev-parse "$highest^{commit}")"
    untagged_between=0
    while IFS= read -r sha; do
      [[ -z "$sha" ]] && continue
      if ! git tag --points-at "$sha" | grep -q '^v[0-9]'; then
        untagged_between=$((untagged_between + 1))
      fi
    done < <(git rev-list "${second}..${highest_sha}" 2>/dev/null || true)

    if [[ "$untagged_between" -gt 0 ]]; then
      # Gap recovery: e.g. v1.2.38 pushed but v1.2.23–v1.2.37 failed.
      base_semver="${second#v}"
      range="${second}..HEAD"
      echo "Gap detected after $second — backfilling from $range"
      return
    fi
  fi

  base_semver="${highest#v}"
  range="${highest}..HEAD"
}

resolve_range

IFS=. read -r major minor patch <<<"$base_semver"
made=0
NEW_TAGS=()

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
    NEW_TAGS+=("$tag")
  fi
  made=$((made + 1))
done

if [[ "$made" -eq 0 ]]; then
  echo "No untagged commits to backfill."
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run: $made tag(s) would be created."
  exit 0
fi

failed=0
for tag in "${NEW_TAGS[@]}"; do
  if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    echo "Skip $tag (already on origin)"
    continue
  fi
  if git push origin "$tag"; then
    echo "Pushed $tag"
  else
    echo "::error::Failed to push $tag" >&2
    failed=$((failed + 1))
  fi
done

if [[ "$failed" -gt 0 ]]; then
  echo "::error::$failed tag(s) failed to push."
  exit 1
fi

echo "Pushed ${#NEW_TAGS[@]} tag(s)."
