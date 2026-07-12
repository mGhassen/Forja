#!/usr/bin/env bash
set -euo pipefail

# Local release CI menu — lists tags, backfills, and triggers GitHub Actions workflows.
#
# Usage:
#   ./scripts/release_ci.sh              # interactive menu
#   ./scripts/release_ci.sh list-tags    # print all v* tags
#   ./scripts/release_ci.sh backfill     # tag untagged commits (add --dry-run to preview)
#   ./scripts/release_ci.sh release-latest
#   ./scripts/release_ci.sh release TAG=v1.0.2
#   ./scripts/release_ci.sh bump patch|minor|major

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RELEASE_WORKFLOW="release.yml"
BACKFILL_WORKFLOW="backfill-tags.yml"

require_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI required — install https://cli.github.com/" >&2
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh not authenticated — run: gh auth login" >&2
    exit 1
  fi
}

fetch_tags() {
  git fetch origin --tags --force 2>/dev/null || true
}

list_tags() {
  fetch_tags
  echo "Release tags (newest first):"
  local tags
  tags="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname)"
  if [[ -z "$tags" ]]; then
    echo "  (none)"
    return 1
  fi
  local i=1
  while IFS= read -r tag; do
    printf "  %2d) %s\n" "$i" "$tag"
    i=$((i + 1))
  done <<<"$tags"
}

latest_tag() {
  fetch_tags
  git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1
}

normalize_tag() {
  local tag="$1"
  tag="${tag#"${tag%%[![:space:]]*}"}"
  tag="${tag%"${tag##*[![:space:]]}"}"
  if [[ -z "$tag" ]]; then
    echo "error: empty tag" >&2
    exit 1
  fi
  if [[ "$tag" != v* ]]; then
    tag="v${tag}"
  fi
  if ! git rev-parse "$tag" >/dev/null 2>&1; then
    echo "error: tag $tag does not exist" >&2
    exit 1
  fi
  echo "$tag"
}

pick_platforms() {
  PLATFORM_MACOS=true
  PLATFORM_WINDOWS=true
  PLATFORM_LINUX=true
  PLATFORM_ANDROID_TV=false
  PRERELEASE=false

  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    return
  fi

  echo
  echo "Platforms (Enter = keep default):"
  read -r -p "  macOS [Y/n]: " ans
  [[ "$ans" =~ ^[Nn] ]] && PLATFORM_MACOS=false

  read -r -p "  Windows [Y/n]: " ans
  [[ "$ans" =~ ^[Nn] ]] && PLATFORM_WINDOWS=false

  read -r -p "  Linux [Y/n]: " ans
  [[ "$ans" =~ ^[Nn] ]] && PLATFORM_LINUX=false

  read -r -p "  Android TV [y/N]: " ans
  [[ "$ans" =~ ^[Yy] ]] && PLATFORM_ANDROID_TV=true

  read -r -p "  Pre-release [y/N]: " ans
  [[ "$ans" =~ ^[Yy] ]] && PRERELEASE=true
}

trigger_release() {
  local mode="$1"
  local tag="${2:-}"
  require_gh
  pick_platforms

  local -a args=(
    -f "release_mode=$mode"
    -f "tag=$tag"
    -f "bump=${BUMP:-patch}"
    -f "prerelease=$PRERELEASE"
    -f "platform_macos=$PLATFORM_MACOS"
    -f "platform_windows=$PLATFORM_WINDOWS"
    -f "platform_linux=$PLATFORM_LINUX"
    -f "platform_android_tv=$PLATFORM_ANDROID_TV"
  )

  echo "Triggering Release Forja ($mode)…"
  gh workflow run "$RELEASE_WORKFLOW" "${args[@]}"
  gh run list --workflow="$RELEASE_WORKFLOW" --limit 1
  echo "Watch: gh run watch"
}

trigger_backfill() {
  local dry_run="${1:-false}"
  require_gh
  echo "Triggering Backfill version tags (dry_run=$dry_run)…"
  gh workflow run "$BACKFILL_WORKFLOW" -f "dry_run=$dry_run"
  gh run list --workflow="$BACKFILL_WORKFLOW" --limit 1
}

cmd_list_tags() {
  list_tags
}

cmd_backfill() {
  local dry=()
  [[ "${1:-}" == "--dry-run" ]] && dry=(--dry-run)
  ./scripts/backfill_version_tags.sh "${dry[@]}"
}

cmd_release_latest() {
  fetch_tags
  local tag
  tag="$(latest_tag)"
  if [[ -z "$tag" ]]; then
    echo "error: no v* tags — backfill or bump first" >&2
    exit 1
  fi
  echo "Latest tag: $tag"
  trigger_release latest_tag ""
}

cmd_release_tag() {
  fetch_tags
  local raw="${1#TAG=}"
  local tag
  tag="$(normalize_tag "$raw")"
  trigger_release specific_tag "$tag"
}

cmd_bump() {
  local bump="${1:-patch}"
  case "$bump" in
    patch|minor|major) ;;
    *) echo "error: bump must be patch, minor, or major" >&2; exit 1 ;;
  esac
  BUMP="$bump"
  trigger_release bump_new ""
}

interactive_menu() {
  fetch_tags
  echo "Forja release CI"
  echo "================"
  list_tags || true
  echo
  local latest
  latest="$(latest_tag || true)"
  [[ -n "$latest" ]] && echo "Latest: $latest"
  echo
  echo "  1) Release latest tag ($latest)"
  echo "  2) Release a specific tag"
  echo "  3) Bump + release new version"
  echo "  4) Backfill tags (local, push to origin)"
  echo "  5) Backfill tags — dry run (local)"
  echo "  6) Backfill tags (GitHub Actions)"
  echo "  7) List tags"
  echo "  q) Quit"
  echo
  read -r -p "Choice: " choice

  case "$choice" in
    1)
      if [[ -z "$latest" ]]; then
        echo "error: no tags" >&2
        exit 1
      fi
      trigger_release latest_tag ""
      ;;
    2)
      read -r -p "Tag (e.g. v1.0.2): " picked
      cmd_release_tag "TAG=$picked"
      ;;
    3)
      echo "Bump: 1=patch 2=minor 3=major"
      read -r -p "Choice [1]: " bump_choice
      case "${bump_choice:-1}" in
        1) cmd_bump patch ;;
        2) cmd_bump minor ;;
        3) cmd_bump major ;;
        *) echo "invalid"; exit 1 ;;
      esac
      ;;
    4) cmd_backfill ;;
    5) cmd_backfill --dry-run ;;
    6)
      read -r -p "Dry run on GitHub? [y/N]: " dry
      if [[ "$dry" =~ ^[Yy] ]]; then
        trigger_backfill true
      else
        trigger_backfill false
      fi
      ;;
    7) list_tags ;;
    q|Q) exit 0 ;;
    *) echo "invalid choice"; exit 1 ;;
  esac
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    "") interactive_menu ;;
    list-tags) cmd_list_tags ;;
    backfill) cmd_backfill "$@" ;;
    release-latest) cmd_release_latest ;;
    release) cmd_release_tag "$@" ;;
    bump) cmd_bump "$@" ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *)
      echo "error: unknown command: $cmd (try --help)" >&2
      exit 1
      ;;
  esac
}

main "$@"
