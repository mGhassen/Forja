#!/usr/bin/env bash
set -euo pipefail

# Tag every commit on the current branch since the latest v* tag (one patch bump per
# untagged commit, oldest first). Used by .github/workflows/backfill-tags.yml.
#
# Usage:
#   ./scripts/backfill_version_tags.sh          # create and push tags (CI: needs BACKFILL_GITHUB_TOKEN)
#   ./scripts/backfill_version_tags.sh --dry-run
#   ./scripts/backfill_version_tags.sh --range-touches-workflows  # exit 0 if PAT required (CI preflight)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0
CHECK_WORKFLOWS=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --range-touches-workflows) CHECK_WORKFLOWS=1 ;;
  esac
done

cd "$ROOT"
git fetch origin --tags --force 2>/dev/null || true

commit_has_v_tag() {
  git tag --points-at "$1" | grep -q '^v[0-9]'
}

resolve_range() {
  local tag first_untagged latest_base
  first_untagged=""
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    if ! commit_has_v_tag "$sha"; then
      first_untagged="$sha"
      break
    fi
  done < <(git rev-list --first-parent --reverse HEAD 2>/dev/null || true)

  if [[ -z "$first_untagged" ]]; then
    base_semver=""
    range=""
    return
  fi

  latest_base=""
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    if git merge-base --is-ancestor "$(git rev-parse "$tag^{commit}")" "$first_untagged"; then
      latest_base="$tag"
    fi
  done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --merged HEAD --sort=v:refname 2>/dev/null || true)

  if [[ -n "$latest_base" ]]; then
    base_semver="${latest_base#v}"
    range="${latest_base}..HEAD"
    echo "Gap detected after $latest_base — backfilling from $range"
    return
  fi

  base_semver="$(grep '^version:' apps/forja/pubspec.yaml | sed 's/version: *//' | cut -d+ -f1)"
  range="HEAD"
}

range_touches_workflows() {
  local sha
  for sha in $(git rev-list "$range"); do
    commit_has_v_tag "$sha" && continue
    if git diff-tree --no-commit-id --name-only -r "$sha" 2>/dev/null | grep -q '^\.github/workflows/'; then
      return 0
    fi
  done
  return 1
}

resolve_range

if [[ "$CHECK_WORKFLOWS" -eq 1 ]]; then
  if [[ -z "$range" ]]; then
    exit 1
  fi
  if range_touches_workflows; then
    exit 0
  fi
  exit 1
fi

if [[ -z "$range" ]]; then
  echo "No untagged commits to backfill."
  exit 0
fi

IFS=. read -r major minor patch <<<"$base_semver"
made=0
NEW_TAGS=()

for sha in $(git rev-list --reverse "$range"); do
  if commit_has_v_tag "$sha"; then
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
