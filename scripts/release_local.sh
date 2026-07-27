#!/usr/bin/env bash
set -euo pipefail

# Local release → GitHub Release + Cloudflare R2 (no Actions artifacts).
#
# Usage:
#   ./scripts/release_local.sh                         # interactive step wizard
#   ./scripts/release_local.sh bump [patch|minor|major]
#   ./scripts/release_local.sh tag v1.2.404             # build + publish selected platforms
#   ./scripts/release_local.sh backfill [--dry-run]     # tag untagged commits (push)
#   ./scripts/release_local.sh build v1.2.404           # macOS DMG (host arch)
#   ./scripts/release_local.sh build-android-tv v1.2.404  # Android TV APKs (selected ABIs)
#   ./scripts/release_local.sh build-windows v1.2.404   # Windows via Parallels VM
#   ./scripts/release_local.sh setup-windows            # print / run VM toolchain setup
#   ./scripts/release_local.sh publish v1.2.404         # upload dist/ → gh + R2
#   ./scripts/release_local.sh publish-r2 v1.2.404      # upload dist/ → R2 only (retry)
#   ./scripts/release_local.sh sync [v1.2.404]          # push branch (+ tag) → forjahq mirror
#   ./scripts/release_local.sh sync-from [v1.2.404]     # pull CI release commit from forjahq → origin
#
# Interactive wizard (TTY): ↑↓ / j k navigate · Space toggle · Enter next · b back · q quit
#
# Env:
#   FORJA_PRL_VM=Windows 11          Parallels VM name (enables Windows build)
#   FORJA_WIN_REPO=\\Mac\Forja       Windows path to this repo (default share name Forja)
#   FORJA_PLATFORMS=macos_arm64,macos_x86_64,windows,linux,android_tv_arm64,android_tv_armeabi_v7a
#                                    same IDs as release_ci.sh / Actions (one arch per flag).
#                                    Legacy: macos → macos_arm64; android_tv → both TV ABIs.
#                                    Interactive pick if unset; default: macos_arm64 (+windows if VM)
#   FORJA_SYNC_REPO=forjahq/forja    org mirror; force-push after origin (branch + release tag)
#   FORJA_SYNC_SKIP=1                skip org mirror push / pull
#   NONINTERACTIVE=1                 skip confirm / platform prompts
#
# Requires (.env): SUPABASE_*, RELEASE_CDN_URL, FORJA_WEB_URL, R2_*
# Android TV also needs: FORJA_KEYSTORE_PASSWORD, FORJA_KEY_PASSWORD,
#   and FORJA_KEYSTORE_PATH or FORJA_KEYSTORE_BASE64 (optional FORJA_KEY_ALIAS)
# Optional: TURNSTILE_SITE_KEY, SENTRY_DSN, POSTHOG_*

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_DIR="$ROOT/apps/forja"
DIST="$ROOT/dist"
GH_REPO=""
PRL_VM="${FORJA_PRL_VM:-Windows 11}"
# Org mirror of origin (mGhassen/Forja). Override or set FORJA_SYNC_SKIP=1 to disable.
SYNC_REPO="${FORJA_SYNC_REPO:-forjahq/forja}"
SYNC_REMOTE="${FORJA_SYNC_REMOTE:-forjahq}"

if [[ -t 1 ]]; then
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_INV=$'\033[7m'
  C_RESET=$'\033[0m'
else
  C_BOLD="" C_DIM="" C_CYAN="" C_GREEN="" C_YELLOW="" C_RED="" C_INV="" C_RESET=""
fi

die() { echo "${C_RED}error:${C_RESET} $*" >&2; exit 1; }

info() { echo "${C_CYAN}==>${C_RESET} $*"; }
ok() { echo "${C_GREEN}✓${C_RESET} $*"; }
warn() { echo "${C_YELLOW}!${C_RESET} $*"; }

hr() { echo "${C_DIM}────────────────────────────────────────${C_RESET}"; }

require_clean_tree() {
  local dirty
  dirty="$(git status --porcelain 2>/dev/null || true)"
  [[ -z "$dirty" ]] && return 0
  echo "${C_RED}error:${C_RESET} working tree dirty — commit or stash before release" >&2
  echo "${C_DIM}Uncommitted:${C_RESET}" >&2
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '  %s\n' "$line" >&2
  done <<<"$dirty"
  exit 1
}

# ── Interactive TUI (step wizard) ─────────────────────────────────────────────
# Keys: ↑↓ / j k navigate · Space toggle · Enter next · b / ← back · q quit
# UI writes to stderr; selected values print to stdout (or set globals).

_UI_RAW=0
_UI_STTY=""

ui_can() {
  [[ -t 0 && -t 2 && "${NONINTERACTIVE:-}" != "1" ]]
}

ui_hide_cursor() { printf '\033[?25l' >&2; }
ui_show_cursor() { printf '\033[?25h' >&2; }

ui_raw_on() {
  if ((_UI_RAW == 0)); then
    _UI_STTY="$(stty -g 2>/dev/null || true)"
    stty -echo -icanon min 1 time 0 2>/dev/null || true
    _UI_RAW=1
    ui_hide_cursor
  fi
}

ui_raw_off() {
  if ((_UI_RAW == 1)); then
    [[ -n "${_UI_STTY:-}" ]] && stty "$_UI_STTY" 2>/dev/null || true
    _UI_RAW=0
    ui_show_cursor
  fi
}

ui_cleanup() {
  ui_raw_off
}

trap 'ui_cleanup' EXIT INT TERM

# Sets REPLY to key name: up|down|left|right|enter|space|back|quit|<char>
ui_read_key() {
  local k="" rest=""
  ui_raw_on
  IFS= read -rsn1 k || { REPLY=quit; return 1; }
  case "$k" in
    $'\x1b')
      IFS= read -rsn2 -t 0.1 rest || true
      case "$rest" in
        '[A') REPLY=up ;;
        '[B') REPLY=down ;;
        '[C') REPLY=right ;;
        '[D') REPLY=left ;;
        *) REPLY=esc ;;
      esac
      ;;
    '') REPLY=enter ;;
    ' ') REPLY=space ;;
    $'\n'|$'\r') REPLY=enter ;;
    q|Q) REPLY=quit ;;
    b|B) REPLY=back ;;
    j) REPLY=down ;;
    k) REPLY=up ;;
    *) REPLY="$k" ;;
  esac
}

ui_clear() {
  # Home + erase below (avoids full-buffer flash vs \033[2J when redraw is fast).
  printf '\033[H\033[J' >&2
}

# Banner tag line is expensive (walks all v* tags). Cache for the interactive session;
# invalidate after fetch / sync / bump so the label can change.
_UI_TAGS_READY=0
_UI_CACHED_PENDING=""
_UI_CACHED_LATEST=""

ui_invalidate_tags() {
  _UI_TAGS_READY=0
  _UI_CACHED_PENDING=""
  _UI_CACHED_LATEST=""
}

ui_cache_tags() {
  ((_UI_TAGS_READY)) && return 0
  _UI_CACHED_PENDING="$(latest_pending_release_tag 2>/dev/null || true)"
  _UI_CACHED_LATEST="$(default_release_tag 2>/dev/null || true)"
  _UI_TAGS_READY=1
}

ui_step_banner() {
  local step="$1" total="$2" title="$3"
  ui_cache_tags
  echo >&2
  printf '  %sForja%s local release' "${C_BOLD}${C_CYAN}" "${C_RESET}" >&2
  printf '  %s·%s  step %s/%s\n' "${C_DIM}" "${C_RESET}" "$step" "$total" >&2
  printf '  %s%s%s\n' "${C_BOLD}" "$title" "${C_RESET}" >&2
  if [[ -n "$_UI_CACHED_PENDING" ]]; then
    printf '  %slatest tag%s  %s  %s(not on this branch — sync-from)%s\n' \
      "${C_DIM}" "${C_RESET}" "$_UI_CACHED_PENDING" "${C_YELLOW}" "${C_RESET}" >&2
  elif [[ -n "$_UI_CACHED_LATEST" ]]; then
    printf '  %slatest tag%s  %s\n' "${C_DIM}" "${C_RESET}" "$_UI_CACHED_LATEST" >&2
  fi
  hr >&2
  echo >&2
}

ui_hint() {
  printf '  %s%s%s\n' "${C_DIM}" "$*" "${C_RESET}" >&2
}

# Single-select list. Args: step total title -- "id|label" ...
# Prints selected id to stdout. Exit 0=ok 2=back 3=quit
ui_choose() {
  local step="$1" total="$2" title="$3"
  shift 3
  [[ "${1:-}" == "--" ]] && shift
  local -a ids=() labels=()
  local item id label
  for item in "$@"; do
    id="${item%%|*}"
    label="${item#*|}"
    ids+=("$id")
    labels+=("$label")
  done
  ((${#ids[@]} > 0)) || die "ui_choose: empty list"

  local cursor=0 n=${#ids[@]}
  while true; do
    ui_clear
    ui_step_banner "$step" "$total" "$title"
    local i
    for ((i = 0; i < n; i++)); do
      if ((i == cursor)); then
        printf '  %s › %s %s\n' "${C_INV}${C_BOLD}" "${labels[$i]}" "${C_RESET}" >&2
      else
        printf '    %s\n' "${labels[$i]}" >&2
      fi
    done
    echo >&2
    ui_hint "↑↓ navigate · Enter next · b back · q quit"
    ui_read_key
    case "$REPLY" in
      up) cursor=$(( (cursor - 1 + n) % n )) ;;
      down) cursor=$(( (cursor + 1) % n )) ;;
      enter)
        ui_raw_off
        printf '%s\n' "${ids[$cursor]}"
        return 0
        ;;
      back|left)
        ui_raw_off
        return 2
        ;;
      quit|esc)
        ui_raw_off
        return 3
        ;;
    esac
  done
}

# Multi-select checkboxes. Args: step total title -- "id|label|0|1" ...
# Prints selected ids (comma-separated) to stdout. Exit 0=ok 2=back 3=quit
ui_checklist() {
  local step="$1" total="$2" title="$3"
  shift 3
  [[ "${1:-}" == "--" ]] && shift
  local -a ids=() labels=() checked=()
  local item id label on rest
  for item in "$@"; do
    id="${item%%|*}"
    rest="${item#*|}"
    label="${rest%%|*}"
    on="${rest##*|}"
    ids+=("$id")
    labels+=("$label")
    if [[ "$on" == "1" || "$on" == "true" ]]; then
      checked+=(1)
    else
      checked+=(0)
    fi
  done
  ((${#ids[@]} > 0)) || die "ui_checklist: empty list"

  local cursor=0 n=${#ids[@]} i box
  while true; do
    ui_clear
    ui_step_banner "$step" "$total" "$title"
    for ((i = 0; i < n; i++)); do
      if ((checked[i])); then
        box="${C_GREEN}☑${C_RESET}"
      else
        box="${C_DIM}☐${C_RESET}"
      fi
      if ((i == cursor)); then
        printf '  %s›%s %s %s%s%s\n' "${C_CYAN}${C_BOLD}" "${C_RESET}" "$box" "${C_BOLD}" "${labels[$i]}" "${C_RESET}" >&2
      else
        printf '    %s %s\n' "$box" "${labels[$i]}" >&2
      fi
    done
    echo >&2
    ui_hint "↑↓ navigate · Space toggle · Enter next · b back · q quit"
    ui_read_key
    case "$REPLY" in
      up) cursor=$(( (cursor - 1 + n) % n )) ;;
      down) cursor=$(( (cursor + 1) % n )) ;;
      space)
        if ((checked[cursor])); then
          checked[cursor]=0
        else
          checked[cursor]=1
        fi
        ;;
      enter)
        local -a selected=()
        for ((i = 0; i < n; i++)); do
          ((checked[i])) && selected+=("${ids[$i]}")
        done
        if ((${#selected[@]} == 0)); then
          printf '\a' >&2
          continue
        fi
        ui_raw_off
        local IFS=,
        printf '%s\n' "${selected[*]}"
        return 0
        ;;
      back|left)
        ui_raw_off
        return 2
        ;;
      quit|esc)
        ui_raw_off
        return 3
        ;;
    esac
  done
}

# Yes/No. Default yes if $2 is 1. Exit 0=yes 1=no 2=back 3=quit
ui_confirm_screen() {
  local step="$1" total="$2" title="$3" detail="${4:-}" default_yes="${5:-1}"
  local cursor=0
  ((default_yes)) || cursor=1
  local -a labels=("Yes — continue" "No — abort")
  while true; do
    ui_clear
    ui_step_banner "$step" "$total" "$title"
    if [[ -n "$detail" ]]; then
      while IFS= read -r line; do
        printf '  %s\n' "$line" >&2
      done <<<"$detail"
      echo >&2
    fi
    local i
    for ((i = 0; i < 2; i++)); do
      if ((i == cursor)); then
        printf '  %s › %s %s\n' "${C_INV}${C_BOLD}" "${labels[$i]}" "${C_RESET}" >&2
      else
        printf '    %s\n' "${labels[$i]}" >&2
      fi
    done
    echo >&2
    ui_hint "↑↓ navigate · Enter next · b back · q quit"
    ui_read_key
    case "$REPLY" in
      up|down|left|right) cursor=$((1 - cursor)) ;;
      enter)
        ui_raw_off
        ((cursor == 0)) && return 0
        return 1
        ;;
      back)
        ui_raw_off
        return 2
        ;;
      quit|esc)
        ui_raw_off
        return 3
        ;;
    esac
  done
}

ui_input() {
  local step="$1" total="$2" title="$3" prompt="$4" default="${5:-}"
  local ans
  ui_raw_off
  ui_clear
  ui_step_banner "$step" "$total" "$title"
  ui_hint "Enter confirm · leave empty for default · Ctrl-C quit"
  echo >&2
  if [[ -n "$default" ]]; then
    read -r -p "  ${prompt} [${default}]: " ans || return 3
    printf '%s\n' "${ans:-$default}"
  else
    read -r -p "  ${prompt}: " ans || return 3
    printf '%s\n' "$ans"
  fi
}

ui_abort() {
  ui_raw_off
  echo >&2
  die "aborted"
}

gh_repo() {
  if [[ -n "$GH_REPO" ]]; then
    echo "$GH_REPO"
    return
  fi
  local url owner_repo
  url="$(git remote get-url origin 2>/dev/null || true)"
  [[ -n "$url" ]] || die "git remote origin not set"
  owner_repo="$(
    printf '%s\n' "$url" | sed -E \
      -e 's#^git@github\.com:##' \
      -e 's#^https://github\.com/##' \
      -e 's#^ssh://git@github\.com/##' \
      -e 's#\.git$##'
  )"
  [[ "$owner_repo" == */* ]] || die "cannot parse owner/repo from origin: $url"
  GH_REPO="$owner_repo"
  echo "$GH_REPO"
}

gh_r() {
  gh -R "$(gh_repo)" "$@"
}

# Bidirectional mirror with forjahq:
#   sync_to_forjahq   — origin (mGhassen) → forjahq (force; before / after local publish)
#   sync_from_forjahq — forjahq → origin (after CI "New version" creates chore: release)
ensure_sync_remote() {
  local url="https://github.com/${SYNC_REPO}.git"
  if git remote get-url "$SYNC_REMOTE" >/dev/null 2>&1; then
    local cur
    cur="$(git remote get-url "$SYNC_REMOTE")"
    if [[ "$cur" != "$url" && "$cur" != "${url%.git}" && "$cur" != "git@github.com:${SYNC_REPO}.git" ]]; then
      warn "remote '$SYNC_REMOTE' is $cur (expected $url) — using configured URL"
      git remote set-url "$SYNC_REMOTE" "$url"
    fi
    return 0
  fi
  git remote add "$SYNC_REMOTE" "$url"
  ok "added remote $SYNC_REMOTE → $SYNC_REPO"
}

# Tag is on our history: already merged into HEAD, or a 1-commit side branch off it
# (forjahq Actions "chore: release vX.Y.Z" after sync-to force-pushed past it).
tag_on_our_line() {
  local tag="$1"
  local tip parent
  tip="$(git rev-parse "${tag}^{commit}" 2>/dev/null)" || return 1
  if git merge-base --is-ancestor "$tip" HEAD 2>/dev/null; then
    return 0
  fi
  parent="$(git rev-parse "${tip}^" 2>/dev/null)" || return 1
  git merge-base --is-ancestor "$parent" HEAD 2>/dev/null
}

# Newest v* tag that is an ancestor of ref (e.g. forjahq/main after CI release).
latest_tag_on_ref() {
  local ref="$1"
  local t
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    if git merge-base --is-ancestor "$t" "$ref" 2>/dev/null; then
      echo "$t"
      return 0
    fi
  done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null || true)
  return 1
}

# True if tag $1 is a newer semver than tag $2 (vX.Y.Z).
version_tag_gt() {
  local a="$1" b="$2"
  [[ "$a" == "$b" ]] && return 1
  [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" == "$a" ]]
}

# Newest release tag whose commit is on HEAD.
latest_tag_on_head() {
  latest_tag_on_ref HEAD
}

# Newest CI release on our line that is NOT on HEAD and is newer than HEAD's tip tag.
# Ignores ancient orphaned tags (e.g. v1.3.0 still dangling after main moved to v1.3.33).
latest_pending_release_tag() {
  local t tip on_head
  on_head="$(latest_tag_on_head || true)"
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    tip="$(git rev-parse "${t}^{commit}" 2>/dev/null)" || continue
    git merge-base --is-ancestor "$tip" HEAD 2>/dev/null && continue
    tag_on_our_line "$t" || continue
    if [[ -n "$on_head" ]] && ! version_tag_gt "$t" "$on_head"; then
      continue
    fi
    echo "$t"
    return 0
  done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null || true)
  return 1
}

sync_to_forjahq() {
  local tag="${1:-}"
  local branch pending

  if [[ "${FORJA_SYNC_SKIP:-}" == "1" || -z "${SYNC_REPO}" ]]; then
    return 0
  fi

  require_cmd git
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" != "HEAD" ]] || die "detached HEAD — checkout a branch before syncing to $SYNC_REPO"

  ensure_sync_remote
  git fetch "$SYNC_REMOTE" --tags --force 2>/dev/null || true

  # Force-pushing main without the CI release commit orphans it (tag stays, branch moves).
  if pending="$(latest_pending_release_tag)"; then
    die "CI release ${pending} is not on ${branch} yet — run: ./scripts/release_local.sh sync-from ${pending}"
  fi

  info "Sync origin → ${SYNC_REPO} (force branch ${branch}${tag:+, tag ${tag}})"

  if ! git push --force "$SYNC_REMOTE" "HEAD:refs/heads/${branch}"; then
    die "failed to force-push ${branch} → ${SYNC_REPO} (check write access / credentials)"
  fi
  if [[ -n "$tag" ]]; then
    git rev-parse "$tag" >/dev/null 2>&1 || die "tag $tag does not exist locally"
    if ! git push --force "$SYNC_REMOTE" "refs/tags/${tag}"; then
      die "failed to force-push tag ${tag} → ${SYNC_REPO}"
    fi
  fi
  ok "Synced to https://github.com/${SYNC_REPO}"
  ui_invalidate_tags
}

# Pull the CI release commit (+ tag) from forjahq into the current branch and push origin.
# Happy path after Actions "New version" on forjahq: fast-forward. If histories diverged, merge.
# Also finds release tags orphaned by a prior sync-to force-push (not on forjahq/main tip).
sync_from_forjahq() {
  local tag="${1:-}"
  local branch remote_ref release_sha

  if [[ "${FORJA_SYNC_SKIP:-}" == "1" || -z "${SYNC_REPO}" ]]; then
    return 0
  fi

  require_cmd git
  require_clean_tree
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" != "HEAD" ]] || die "detached HEAD — checkout a branch before syncing from $SYNC_REPO"

  ensure_sync_remote
  info "Fetch ${SYNC_REPO} (bring CI release → origin)"
  git fetch "$SYNC_REMOTE" --tags --force
  git fetch origin --tags --force 2>/dev/null || true

  remote_ref="${SYNC_REMOTE}/${branch}"
  git rev-parse "$remote_ref" >/dev/null 2>&1 \
    || die "missing ${remote_ref} after fetch — does ${SYNC_REPO} have branch ${branch}?"

  if [[ -n "$tag" ]]; then
    [[ "$tag" == v* ]] || tag="v${tag}"
    git rev-parse "$tag" >/dev/null 2>&1 || die "tag $tag not found after fetch from ${SYNC_REPO}"
  else
    # Prefer orphaned CI release not yet on HEAD; else newest tag on remote tip.
    tag="$(latest_pending_release_tag || true)"
    if [[ -z "$tag" ]]; then
      tag="$(latest_tag_on_ref "$remote_ref")" \
        || die "no v* tags found on ${remote_ref}"
    fi
  fi

  release_sha="$(git rev-parse "${tag}^{commit}")"
  info "Release ${tag} @ ${release_sha:0:8} from ${SYNC_REPO}"

  if git merge-base --is-ancestor "$release_sha" HEAD; then
    ok "${tag} already on ${branch}"
  elif git merge-base --is-ancestor HEAD "$release_sha"; then
    info "Fast-forward ${branch} → ${tag}"
    git merge --ff-only "$release_sha"
  else
    warn "Histories diverged — merging ${tag} into ${branch} (keeps tagged SHA)"
    if ! git merge --no-edit -m "chore: sync release ${tag} from ${SYNC_REPO}" "$release_sha"; then
      die "merge conflict — resolve, then: git push origin HEAD && git push origin ${tag}"
    fi
  fi

  if ! git push origin "HEAD:refs/heads/${branch}"; then
    die "failed to push ${branch} → origin (check write access / credentials)"
  fi
  if ! git push origin "refs/tags/${tag}"; then
    die "failed to push tag ${tag} → origin (tag may already exist with a different SHA)"
  fi
  # Keep forjahq/main in sync after merge (non-force: only if we advanced).
  if ! git push "$SYNC_REMOTE" "HEAD:refs/heads/${branch}"; then
    warn "merged locally + origin, but push to ${SYNC_REPO} failed — run sync after fixing access"
  else
    ok "Updated ${SYNC_REPO} ${branch} with ${tag}"
  fi
  ok "Brought ${tag} from ${SYNC_REPO} → origin ($(gh_repo))"
  ui_invalidate_tags
}

load_env() {
  local f="$ROOT/.env"
  [[ -f "$f" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
  if [[ -z "${SUPABASE_PUBLISHABLE_KEY:-}" && -n "${SUPABASE_ANON_KEY:-}" ]]; then
    SUPABASE_PUBLISHABLE_KEY="$SUPABASE_ANON_KEY"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

require_darwin() {
  [[ "$(uname -s)" == Darwin ]] || die "macOS host required (got $(uname -s))"
}

require_build_env() {
  require_darwin
  require_cmd flutter
  require_cmd cargo
  require_cmd hdiutil
  [[ -n "${SUPABASE_URL:-}" ]] || die "SUPABASE_URL missing (set in .env)"
  [[ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]] || die "SUPABASE_PUBLISHABLE_KEY missing (set in .env)"
  [[ -n "${RELEASE_CDN_URL:-}" ]] || die "RELEASE_CDN_URL missing (set in .env)"
  [[ -n "${FORJA_WEB_URL:-}" ]] || die "FORJA_WEB_URL missing (set in .env)"
  case "$FORJA_WEB_URL" in
    http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*)
      die "FORJA_WEB_URL must be the public portal URL, not localhost"
      ;;
  esac
}

require_publish_env() {
  require_cmd gh
  gh auth status >/dev/null 2>&1 || die "gh not authenticated — run: gh auth login"
  [[ -n "${R2_ACCESS_KEY_ID:-}" ]] || die "R2_ACCESS_KEY_ID missing (set in .env)"
  [[ -n "${R2_SECRET_ACCESS_KEY:-}" ]] || die "R2_SECRET_ACCESS_KEY missing (set in .env)"
}

normalize_tag() {
  local tag="$1"
  tag="${tag#"${tag%%[![:space:]]*}"}"
  tag="${tag%"${tag##*[![:space:]]}"}"
  [[ -n "$tag" ]] || die "empty tag"
  [[ "$tag" == v* ]] || tag="v${tag}"
  git rev-parse "$tag" >/dev/null 2>&1 || die "tag $tag does not exist"
  echo "$tag"
}

version_from_tag() {
  echo "${1#v}"
}

dmg_path() { echo "$DIST/Forja-${1}-macos-${2:-arm64}.dmg"; }
exe_path() { echo "$DIST/Forja-${1}-windows-setup.exe"; }

confirm() {
  local prompt="${1:-Continue?}"
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    return 0
  fi
  if ui_can; then
    ui_confirm_screen 1 1 "$prompt" "" 0
    return $?
  fi
  local ans
  read -r -p "${C_BOLD}${prompt}${C_RESET} [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Default yes (Enter accepts).
confirm_yes() {
  local prompt="${1:-Continue?}"
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    return 0
  fi
  if ui_can; then
    ui_confirm_screen 1 1 "$prompt" "" 1
    return $?
  fi
  local ans
  read -r -p "${C_BOLD}${prompt}${C_RESET} [Y/n]: " ans
  [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]
}

fetch_tags() {
  git fetch origin --tags --force 2>/dev/null || true
  ui_invalidate_tags
}

latest_tag() {
  git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -1
}

# Prefer newest tag on the pubspec major.minor arc that is on our history line
# (merged into HEAD, or a CI release commit that branched off HEAD's ancestors).
# Ancestor-only missed forjahq "chore: release" tags after sync-to force-pushed past them.
default_release_tag() {
  local semver major minor t
  semver="$(grep '^version:' "$APP_DIR/pubspec.yaml" 2>/dev/null | sed 's/version: *//' | cut -d+ -f1 || true)"
  if [[ "$semver" =~ ^([0-9]+)\.([0-9]+)\. ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      if tag_on_our_line "$t"; then
        echo "$t"
        return
      fi
    done < <(git tag -l "v${major}.${minor}.*" --sort=-v:refname 2>/dev/null || true)
  fi
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    if tag_on_our_line "$t"; then
      echo "$t"
      return
    fi
  done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null || true)
}

list_tags() {
  local filter="${1:-}" tags
  fetch_tags
  tags="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname)"
  if [[ -n "$filter" ]]; then
    tags="$(grep -i "$filter" <<<"$tags" || true)"
  fi
  if [[ -z "$tags" ]]; then
    echo "  ${C_DIM}(none)${C_RESET}"
    return 1
  fi
  local i=1
  while IFS= read -r tag; do
    printf "  ${C_DIM}%2d)${C_RESET} %s\n" "$i" "$tag"
    i=$((i + 1))
  done <<<"$tags"
}

pick_tag_interactive() {
  # UI → stderr so `tag="$(pick_tag_interactive)"` only captures the tag.
  fetch_tags
  local filter tags tag default show_n=20 rc
  default="$(default_release_tag)"
  [[ -n "$default" ]] || die "no v* tags found"

  if ! ui_can; then
    local picked i
    echo >&2
    echo "  ${C_BOLD}latest${C_RESET}  ${C_GREEN}${default}${C_RESET}  ${C_DIM}(Enter)${C_RESET}" >&2
    read -r -p "Filter (empty = recent ${show_n}, e.g. 1.2): " filter
    tags="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname)"
    if [[ -n "$filter" ]]; then
      tags="$(grep -i "$filter" <<<"$tags" || true)"
    else
      tags="$(
        {
          echo "$default"
          arc="${default%.*}"
          git tag -l "${arc}.*" --sort=-v:refname | grep -vxF "$default" || true
          grep -vxF "$default" <<<"$tags" || true
        } | awk 'NF && !seen[$0]++' | head -n "$show_n"
      )"
    fi
    [[ -n "$tags" ]] || die "no tags match"
    default="$(head -1 <<<"$tags")"
    echo >&2
    i=1
    while IFS= read -r t; do
      if ((i == 1)); then
        printf "  ${C_GREEN}%2d)${C_RESET} ${C_BOLD}%s${C_RESET}  ${C_DIM}← Enter${C_RESET}\n" "$i" "$t" >&2
      else
        printf "  ${C_DIM}%2d)${C_RESET} %s\n" "$i" "$t" >&2
      fi
      i=$((i + 1))
    done <<<"$tags"
    echo >&2
    read -r -p "Pick number or type tag [${default}]: " picked
    if [[ -z "$picked" ]]; then
      printf '%s\n' "$default"
      return
    fi
    if [[ "$picked" =~ ^[0-9]+$ ]]; then
      tag="$(sed -n "${picked}p" <<<"$tags")"
      [[ -n "$tag" ]] || die "invalid number"
    else
      tag="$(normalize_tag "$picked")"
    fi
    printf '%s\n' "$tag"
    return
  fi

  filter="$(ui_input 1 2 "Filter tags" "Filter (empty = recent ${show_n})" "")" || ui_abort
  tags="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname)"
  if [[ -n "$filter" ]]; then
    tags="$(grep -i "$filter" <<<"$tags" || true)"
  else
    tags="$(
      {
        echo "$default"
        arc="${default%.*}"
        git tag -l "${arc}.*" --sort=-v:refname | grep -vxF "$default" || true
        grep -vxF "$default" <<<"$tags" || true
      } | awk 'NF && !seen[$0]++' | head -n "$show_n"
    )"
  fi
  [[ -n "$tags" ]] || die "no tags match"

  local -a choices=()
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    choices+=("${t}|${t}")
  done <<<"$tags"

  tag="$(ui_choose 2 2 "Pick release tag" -- "${choices[@]}")" || {
    rc=$?
    ((rc == 2)) && return 2
    ui_abort
  }
  printf '%s\n' "$tag"
}

pick_bump() {
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    printf '%s\n' "${1:-patch}"
    return
  fi
  if ! ui_can; then
    local bump_choice
    echo >&2
    echo "Bump type:" >&2
    echo "  ${C_DIM}1)${C_RESET} patch   ${C_DIM}(default)${C_RESET}" >&2
    echo "  ${C_DIM}2)${C_RESET} minor" >&2
    echo "  ${C_DIM}3)${C_RESET} major" >&2
    read -r -p "Choice [1]: " bump_choice
    case "${bump_choice:-1}" in
      1|patch) printf '%s\n' patch ;;
      2|minor) printf '%s\n' minor ;;
      3|major) printf '%s\n' major ;;
      *) die "invalid bump" ;;
    esac
    return
  fi
  local bump rc
  bump="$(ui_choose 1 1 "Bump type" -- \
    "patch|patch — 1.2.N → 1.2.N+1 (default)" \
    "minor|minor — 1.2.x → 1.3.0" \
    "major|major — 1.x → 2.0.0")" || {
    rc=$?
    ((rc == 2 || rc == 3)) && ui_abort
    ui_abort
  }
  printf '%s\n' "$bump"
}

# Platforms for tag/bump — same IDs as Actions / release_ci.sh.
# Normalize legacy aliases so old FORJA_PLATFORMS=macos,android_tv still work.
normalize_platform_list() {
  local raw="$1"
  local -a out=() part
  local IFS=','
  # shellcheck disable=SC2206
  local -a parts=($raw)
  for part in "${parts[@]}"; do
    part="${part// /}"
    [[ -z "$part" ]] && continue
    case "$part" in
      macos) out+=(macos_arm64) ;;
      android_tv)
        out+=(android_tv_arm64)
        out+=(android_tv_armeabi_v7a)
        ;;
      macos_arm64|macos_x86_64|windows|linux|android_tv_arm64|android_tv_armeabi_v7a)
        out+=("$part")
        ;;
      *)
        die "unknown platform '$part' (want macos_arm64, macos_x86_64, windows, linux, android_tv_arm64, android_tv_armeabi_v7a)"
        ;;
    esac
  done
  ((${#out[@]} > 0)) || die "select at least one platform"
  local IFS=,
  echo "${out[*]}"
}

host_macos_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo arm64 ;;
    *) echo x86_64 ;;
  esac
}

platforms() {
  if [[ -n "${FORJA_PLATFORMS:-}" ]]; then
    normalize_platform_list "$FORJA_PLATFORMS"
    return
  fi
  if command -v prlctl >/dev/null 2>&1 && prlctl list -a 2>/dev/null | grep -q "$PRL_VM"; then
    echo "macos_arm64,windows"
  else
    echo "macos_arm64"
  fi
}

want_platform() {
  local p="$1"
  [[ ",$(platforms)," == *",$p,"* ]]
}

# Interactive checklist → FORJA_PLATFORMS (same surface as release_ci.sh / Actions).
pick_platforms() {
  if [[ -n "${FORJA_PLATFORMS:-}" || "${NONINTERACTIVE:-}" == "1" ]]; then
    if [[ -n "${FORJA_PLATFORMS:-}" ]]; then
      FORJA_PLATFORMS="$(normalize_platform_list "$FORJA_PLATFORMS")"
      export FORJA_PLATFORMS
    fi
    return
  fi

  local win_default=0 win_hint="Windows"
  if command -v prlctl >/dev/null 2>&1 && prlctl list -a 2>/dev/null | grep -q "$PRL_VM"; then
    win_default=1
    win_hint="Windows (Parallels: ${PRL_VM})"
  else
    win_hint="Windows (needs Parallels VM)"
  fi

  if ! ui_can; then
    local macos_arm64=true macos_x86_64=false windows=false linux=false
    local android_tv_arm64=false android_tv_v7a=false ans
    ((win_default)) && windows=true
    echo
    echo "${C_BOLD}Platforms${C_RESET} ${C_DIM}(one arch per line — same as Actions)${C_RESET}"
    read -r -p "  macOS Apple Silicon arm64 [Y/n]: " ans
    [[ "$ans" =~ ^[Nn]$ ]] && macos_arm64=false
    read -r -p "  macOS Intel x86_64 [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && macos_x86_64=true
    if $windows; then
      read -r -p "  Windows [Y/n]: " ans
      [[ "$ans" =~ ^[Nn]$ ]] && windows=false
    else
      read -r -p "  Windows [y/N]: " ans
      [[ "$ans" =~ ^[Yy]$ ]] && windows=true
    fi
    read -r -p "  Linux [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && linux=true
    read -r -p "  Android TV arm64 [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && android_tv_arm64=true
    read -r -p "  Android TV armeabi-v7a [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && android_tv_v7a=true
    local -a selected=()
    $macos_arm64 && selected+=(macos_arm64)
    $macos_x86_64 && selected+=(macos_x86_64)
    $windows && selected+=(windows)
    $linux && selected+=(linux)
    $android_tv_arm64 && selected+=(android_tv_arm64)
    $android_tv_v7a && selected+=(android_tv_armeabi_v7a)
    ((${#selected[@]} > 0)) || die "select at least one platform"
    FORJA_PLATFORMS="$(IFS=,; echo "${selected[*]}")"
    export FORJA_PLATFORMS
    ok "platforms: $FORJA_PLATFORMS"
    return
  fi

  local picked rc
  picked="$(ui_checklist 1 1 "Platforms (one arch each — same as Actions)" -- \
    "macos_arm64|macOS — Apple Silicon only (arm64)|1" \
    "macos_x86_64|macOS — Intel only (x86_64) · CI only on Apple Silicon host|0" \
    "windows|${win_hint}|${win_default}" \
    "linux|Linux (use release_ci.sh)|0" \
    "android_tv_arm64|Android TV — arm64 only|0" \
    "android_tv_armeabi_v7a|Android TV — armeabi-v7a only|0")" || {
    rc=$?
    ((rc == 2)) && return 2
    ui_abort
  }
  FORJA_PLATFORMS="$(normalize_platform_list "$picked")"
  export FORJA_PLATFORMS
  ok "platforms: $FORJA_PLATFORMS"
}

# Default: Parallels share named "Forja" → \\Mac\Forja (see Devices → Shared Folders).
# Override with FORJA_WIN_REPO if your share name/path differs.
win_repo_unc() {
  if [[ -n "${FORJA_WIN_REPO:-}" ]]; then
    echo "$FORJA_WIN_REPO"
    return
  fi
  echo '\\\\Mac\\Forja'
}

# UNC → Git Bash path: \\Mac\Home\a\b → //Mac/Home/a/b
win_repo_bash() {
  local unc
  unc="$(win_repo_unc)"
  echo "$unc" | sed -e 's#^\\\\#//#' -e 's#\\#/#g'
}

prl_ensure_running() {
  require_cmd prlctl
  local status
  status="$(prlctl list -a 2>/dev/null | awk -v n="$PRL_VM" '$0 ~ n {print $2; exit}')"
  [[ -n "$status" ]] || die "Parallels VM not found: $PRL_VM (prlctl list -a)"
  if [[ "$status" != "running" ]]; then
    echo "==> Starting Parallels VM: $PRL_VM"
    prlctl start "$PRL_VM"
    # Wait for guest tools / exec
    local i=0
    while (( i < 60 )); do
      if prlctl exec "$PRL_VM" --current-user cmd /c "echo ok" >/dev/null 2>&1; then
        break
      fi
      sleep 5
      i=$((i + 1))
    done
    prlctl exec "$PRL_VM" --current-user cmd /c "echo ok" >/dev/null 2>&1 \
      || die "VM started but prlctl exec failed — install Parallels Tools and sign in"
  fi
}

build_macos() {
  local ver="$1"
  local arch="${2:-$(host_macos_arch)}"
  local host
  host="$(host_macos_arch)"
  require_build_env
  if [[ "$arch" != "$host" ]]; then
    die "macOS $arch DMG cannot be built on this host ($host). Use Actions / ./scripts/release_ci.sh (macos-15-intel for x86_64)."
  fi
  echo "==> Rust FFI"
  ./scripts/build_rust_release.sh
  echo "==> Flutter macOS $arch ($ver)"
  (
    cd "$APP_DIR"
    flutter pub get
    FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO flutter build macos --release \
      --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
      --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
      --dart-define=RELEASE_CDN_URL="${RELEASE_CDN_URL}" \
      --dart-define=FORJA_WEB_URL="${FORJA_WEB_URL}" \
      --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}" \
      --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
      --dart-define=POSTHOG_API_KEY="${POSTHOG_API_KEY:-}" \
      --dart-define=POSTHOG_HOST="${POSTHOG_HOST:-}"
  )
  echo "==> Ad-hoc codesign"
  ./scripts/codesign_macos_adhoc.sh
  echo "==> Verify payload"
  ./scripts/verify_installer_payload.sh macos
  echo "==> Package DMG ($arch)"
  ./scripts/package_macos_dmg.sh "$ver" "$arch"
  local dmg
  dmg="$(dmg_path "$ver" "$arch")"
  [[ -f "$dmg" ]] || die "expected DMG missing: $dmg"
  ls -lh "$dmg"
}

build_windows_prl() {
  local ver="$1"
  local bash_repo unc
  require_darwin
  require_cmd prlctl
  prl_ensure_running
  unc="$(win_repo_unc)"
  bash_repo="$(win_repo_bash)"
  echo "==> Windows build via Parallels ($PRL_VM)"
  echo "    repo: $unc"
  # Prefer Git Bash so existing .sh scripts run unchanged.
  prlctl exec "$PRL_VM" --current-user \
    "C:\\Program Files\\Git\\bin\\bash.exe" -lc \
    "cd '$bash_repo' && ./scripts/build_windows_release.sh '$ver'" \
    || die "Windows build failed — run scripts/setup_windows_vm.ps1 inside the VM first"
  local exe
  exe="$(exe_path "$ver")"
  [[ -f "$exe" ]] || die "missing $exe after Parallels build (is the repo on a shared folder?)"
  ls -lh "$exe"
}

build_android_tv() {
  local ver="$1"
  shift || true
  local -a abis=("$@")
  local keystore="" tmp_ks="" key_alias
  local -a flutter_targets=() package_abis=()
  require_cmd flutter
  require_cmd keytool
  [[ -n "${SUPABASE_URL:-}" ]] || die "SUPABASE_URL missing (set in .env)"
  [[ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]] || die "SUPABASE_PUBLISHABLE_KEY missing (set in .env)"
  [[ -n "${RELEASE_CDN_URL:-}" ]] || die "RELEASE_CDN_URL missing (set in .env)"
  [[ -n "${FORJA_WEB_URL:-}" ]] || die "FORJA_WEB_URL missing (set in .env)"
  [[ -n "${FORJA_KEYSTORE_PASSWORD:-}" ]] || die "FORJA_KEYSTORE_PASSWORD missing (set in .env)"
  [[ -n "${FORJA_KEY_PASSWORD:-}" ]] || die "FORJA_KEY_PASSWORD missing (set in .env)"

  if [[ ${#abis[@]} -eq 0 ]]; then
    abis=(arm64 armeabi-v7a)
  fi
  local abi
  for abi in "${abis[@]}"; do
    case "$abi" in
      arm64|arm64-v8a)
        flutter_targets+=(android-arm64)
        package_abis+=(arm64)
        ;;
      armeabi-v7a|v7a|arm)
        flutter_targets+=(android-arm)
        package_abis+=(armeabi-v7a)
        ;;
      *)
        die "unknown Android TV ABI '$abi' (want arm64 or armeabi-v7a)"
        ;;
    esac
  done
  ((${#flutter_targets[@]} > 0)) || die "select at least one Android TV ABI"

  if [[ -n "${FORJA_KEYSTORE_PATH:-}" ]]; then
    keystore="$FORJA_KEYSTORE_PATH"
    case "$keystore" in
      /*) ;;
      *) keystore="$ROOT/$keystore" ;;
    esac
    [[ -f "$keystore" ]] || die "FORJA_KEYSTORE_PATH not found: $keystore"
  elif [[ -n "${FORJA_KEYSTORE_BASE64:-}" ]]; then
    tmp_ks="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_ks'" RETURN
    echo "$FORJA_KEYSTORE_BASE64" | base64 -d >"$tmp_ks"
    keystore="$tmp_ks"
  else
    die "Android TV needs FORJA_KEYSTORE_PATH or FORJA_KEYSTORE_BASE64 in .env (same as GitHub secrets)"
  fi

  key_alias="${FORJA_KEY_ALIAS:-forja}"
  if ! keytool -list \
    -keystore "$keystore" \
    -storepass "$FORJA_KEYSTORE_PASSWORD" \
    -alias "$key_alias" >/dev/null 2>&1; then
    warn "No key alias '$key_alias' in keystore. Available:"
    keytool -list -keystore "$keystore" -storepass "$FORJA_KEYSTORE_PASSWORD" || true
    die "fix FORJA_KEY_ALIAS / keystore"
  fi

  local target_platform
  local IFS=,
  target_platform="${flutter_targets[*]}"
  unset IFS

  info "Flutter Android TV APKs ($ver) — ${package_abis[*]}"
  (
    cd "$APP_DIR"
    flutter pub get
    flutter build apk --release --split-per-abi \
      --target-platform "$target_platform" \
      --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
      --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
      --dart-define=RELEASE_CDN_URL="${RELEASE_CDN_URL}" \
      --dart-define=FORJA_WEB_URL="${FORJA_WEB_URL}" \
      --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}" \
      --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
      --dart-define=POSTHOG_API_KEY="${POSTHOG_API_KEY:-}" \
      --dart-define=POSTHOG_HOST="${POSTHOG_HOST:-}" \
      -PFORJA_KEYSTORE_PATH="$keystore" \
      -PFORJA_KEYSTORE_PASSWORD="${FORJA_KEYSTORE_PASSWORD}" \
      -PFORJA_KEY_ALIAS="$key_alias" \
      -PFORJA_KEY_PASSWORD="${FORJA_KEY_PASSWORD}"
  )
  ./scripts/package_android_tv_apk.sh "$ver" "${package_abis[@]}"
  local out
  for abi in "${package_abis[@]}"; do
    out="$DIST/Forja-${ver}-android-tv-${abi}.apk"
    [[ -f "$out" ]] || die "missing $out"
    ls -lh "$out"
  done
}

collect_assets() {
  local ver="$1"
  local -a files=()
  local f
  # Publish whatever was built into dist/ for this version (platforms gate build only).
  for f in \
    "$(dmg_path "$ver" arm64)" \
    "$(dmg_path "$ver" x86_64)" \
    "$(exe_path "$ver")" \
    "$DIST/Forja-${ver}-linux-x86_64.AppImage" \
    "$DIST/Forja-${ver}-android-tv-arm64.apk" \
    "$DIST/Forja-${ver}-android-tv-armeabi-v7a.apk"; do
    [[ -f "$f" ]] && files+=("$f")
  done
  ((${#files[@]} > 0)) || die "no installers in dist/ for $ver"
  printf '%s\n' "${files[@]}"
}

publish_github() {
  # mode: assets (default) — notes + upload installers; notes — changelog only
  local ver="$1"
  local mode="${2:-assets}"
  local tag="v${ver}"
  local notes repo
  local -a assets=()
  repo="$(gh_repo)"
  notes="$(mktemp)"
  ./scripts/changelog_release_notes.sh "$ver" "$notes"
  if [[ "$mode" == assets ]]; then
    mapfile -t assets < <(collect_assets "$ver")
  fi
  if gh_r release view "$tag" >/dev/null 2>&1; then
    echo "==> Updating GitHub release $tag ($repo) [${mode}]"
    if grep -q '^### ' "$notes"; then
      gh_r release edit "$tag" --title "Forja ${ver}" --notes-file "$notes"
    else
      warn "No changelog groups for $ver — release notes left unchanged"
    fi
    if [[ "$mode" == assets ]]; then
      gh_r release upload "$tag" "${assets[@]}" --clobber
    fi
  else
    echo "==> Creating GitHub release $tag ($repo) [${mode}]"
    local -a args=(
      "$tag"
      --title "Forja ${ver}"
      --verify-tag
    )
    if [[ "$mode" == assets ]]; then
      args+=("${assets[@]}")
    fi
    if [[ "${PRERELEASE:-}" == "1" ]]; then
      args+=(--prerelease)
    fi
    if grep -q '^### ' "$notes"; then
      args+=(--notes-file "$notes")
    else
      args+=(--generate-notes)
    fi
    gh_r release create "${args[@]}"
  fi
  rm -f "$notes"
  echo "GitHub: https://github.com/${repo}/releases/tag/${tag}"
  if [[ "$mode" == assets ]]; then
    printf '  asset: %s\n' "${assets[@]}"
  else
    echo "  (changelog notes only — no assets uploaded)"
  fi
}

publish_r2() {
  local ver="$1"
  local flat f
  flat="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$flat'" RETURN
  mkdir -p "$flat"
  while IFS= read -r f; do
    cp -f "$f" "$flat/"
  done < <(collect_assets "$ver")
  echo "==> Upload to R2"
  export R2_BUCKET="${R2_BUCKET:-forja-releases}"
  export RELEASE_STORAGE_KEEP="${RELEASE_STORAGE_KEEP:-3}"
  ./scripts/upload_release_to_r2.sh "$ver" "$flat"
}

build_selected() {
  local ver="$1"
  local -a tv_abis=()
  if want_platform linux; then
    [[ "$(uname -s)" == Linux ]] \
      || die "Linux AppImage builds need a Linux host — use ./scripts/release_ci.sh"
    die "local Linux AppImage build not wired — use ./scripts/release_ci.sh"
  fi
  if want_platform macos_arm64; then
    build_macos "$ver" arm64
  fi
  if want_platform macos_x86_64; then
    build_macos "$ver" x86_64
  fi
  if want_platform windows; then
    build_windows_prl "$ver"
  fi
  if want_platform android_tv_arm64; then
    tv_abis+=(arm64)
  fi
  if want_platform android_tv_armeabi_v7a; then
    tv_abis+=(armeabi-v7a)
  fi
  if ((${#tv_abis[@]} > 0)); then
    build_android_tv "$ver" "${tv_abis[@]}"
  fi
}

cmd_build() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  info "Build macOS DMG for $tag ($(host_macos_arch))"
  build_macos "$ver" "$(host_macos_arch)"
}

cmd_build_windows() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  info "Build Windows installer for $tag via Parallels ($PRL_VM)"
  confirm "Start Windows build in VM?" || die "aborted"
  build_windows_prl "$ver"
}

cmd_build_android_tv() {
  local tag ver
  local -a abis=()
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  if [[ -n "${FORJA_PLATFORMS:-}" ]]; then
    want_platform android_tv_arm64 && abis+=(arm64)
    want_platform android_tv_armeabi_v7a && abis+=(armeabi-v7a)
  fi
  if ((${#abis[@]} == 0)); then
    abis=(arm64 armeabi-v7a)
  fi
  info "Build Android TV APKs for $tag (${abis[*]})"
  confirm "Start Android TV release build?" || die "aborted"
  build_android_tv "$ver" "${abis[@]}"
  ok "APKs in dist/ for $ver"
}

cmd_setup_windows() {
  require_darwin
  local unc bash_repo
  unc="$(win_repo_unc)"
  bash_repo="$(win_repo_bash)"
  echo "Windows VM toolchain setup"
  echo "=========================="
  echo "VM:   $PRL_VM"
  echo "Repo: $unc"
  echo
  echo "1) In the VM: open elevated PowerShell"
  echo "2) Run:"
  echo "   Set-ExecutionPolicy Bypass -Scope Process -Force"
  echo "   cd '$unc'"
  echo "   .\\scripts\\setup_windows_vm.ps1"
  echo
  if command -v prlctl >/dev/null 2>&1; then
    if confirm "Try launching setup via prlctl now? (still needs Admin inside guest)"; then
      prl_ensure_running
      prlctl exec "$PRL_VM" --current-user powershell \
        -NoProfile -ExecutionPolicy Bypass \
        -Command "Set-Location '$unc'; & '.\\scripts\\setup_windows_vm.ps1'" \
        || echo "prlctl setup failed (elevate manually inside the VM)."
    fi
  fi
}

cmd_publish() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  require_publish_env
  info "Publish $tag → GitHub + R2"
  collect_assets "$ver" >/dev/null
  confirm "Upload dist assets for $ver to GitHub + R2?" || die "aborted"
  publish_github "$ver" assets
  publish_r2 "$ver"
  if [[ "${FORJA_SYNC_SKIP:-}" != "1" ]]; then
    sync_to_forjahq "$tag"
  else
    warn "Skipped mirror sync (${SYNC_REPO})"
  fi
  ok "Done: $tag"
}

# Selective publish used by the interactive tools wizard.
# gh_mode: assets | notes | skip · do_r2: 0|1 · do_sync: 0|1
cmd_publish_parts() {
  local tag ver gh_mode do_r2 do_sync
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  gh_mode="${2:-assets}"
  do_r2="${3:-0}"
  do_sync="${4:-0}"

  case "$gh_mode" in
    assets|notes|skip) ;;
    *) die "invalid GitHub mode: $gh_mode (assets|notes|skip)" ;;
  esac
  if [[ "$gh_mode" == skip ]] && [[ "$do_r2" != "1" ]]; then
    die "nothing to publish — pick GitHub and/or R2"
  fi

  if [[ "$gh_mode" != skip ]]; then
    require_cmd gh
    gh auth status >/dev/null 2>&1 || die "gh not authenticated — run: gh auth login"
  fi
  if [[ "$gh_mode" == assets || "$do_r2" == "1" ]]; then
    collect_assets "$ver" >/dev/null
  fi
  if [[ "$do_r2" == "1" ]]; then
    [[ -n "${R2_ACCESS_KEY_ID:-}" ]] || die "R2_ACCESS_KEY_ID missing (set in .env)"
    [[ -n "${R2_SECRET_ACCESS_KEY:-}" ]] || die "R2_SECRET_ACCESS_KEY missing (set in .env)"
  fi

  info "Publish $tag (github=${gh_mode}, r2=${do_r2}, sync=${do_sync})"
  if [[ "$gh_mode" != skip ]]; then
    publish_github "$ver" "$gh_mode"
  else
    warn "Skipped GitHub"
  fi
  if [[ "$do_r2" == "1" ]]; then
    publish_r2 "$ver"
  else
    warn "Skipped R2"
  fi
  if [[ "$do_sync" == "1" ]]; then
    FORJA_SYNC_SKIP=0 sync_to_forjahq "$tag"
  else
    warn "Skipped mirror sync (${SYNC_REPO})"
  fi
  ok "Done: $tag"
}

cmd_publish_r2() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  [[ -n "${R2_ACCESS_KEY_ID:-}" ]] || die "R2_ACCESS_KEY_ID missing (set in .env)"
  [[ -n "${R2_SECRET_ACCESS_KEY:-}" ]] || die "R2_SECRET_ACCESS_KEY missing (set in .env)"
  info "Upload $tag → R2 only"
  collect_assets "$ver" >/dev/null
  confirm "Upload dist assets for $ver to R2 (skip GitHub)?" || die "aborted"
  publish_r2 "$ver"
  ok "R2 upload done: $tag"
}

cmd_sync() {
  local tag=""
  if [[ -n "${1:-}" ]]; then
    tag="$(normalize_tag "$1")"
  else
    tag="$(default_release_tag)"
    [[ -n "$tag" ]] || die "no v* tags found — pass a tag: release_local.sh sync vX.Y.Z"
  fi
  require_cmd git
  info "Mirror sync → ${SYNC_REPO} (${tag})"
  confirm "Force-push current branch + ${tag} to ${SYNC_REPO} (mirror overwrite)?" || die "aborted"
  FORJA_SYNC_SKIP=0 sync_to_forjahq "$tag"
}

cmd_sync_from() {
  local tag="${1:-}"
  require_cmd git
  if [[ -n "$tag" ]]; then
    [[ "$tag" == v* ]] || tag="v${tag}"
  fi
  info "Mirror sync ← ${SYNC_REPO}${tag:+ (${tag})} → origin"
  confirm "Fetch CI release from ${SYNC_REPO} and push branch + tag to origin?" || die "aborted"
  FORJA_SYNC_SKIP=0 sync_from_forjahq "$tag"
}

cmd_backfill() {
  local -a dry=()
  [[ "${1:-}" == "--dry-run" ]] && dry=(--dry-run)
  require_cmd git
  info "Backfill version tags${dry[*]:+ (${dry[*]})}"
  ./scripts/backfill_version_tags.sh "${dry[@]}"
}

cmd_tag() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  require_publish_env
  info "Local release $tag (platforms: $(platforms))"
  confirm "Build and publish $tag?" || die "aborted"
  build_selected "$ver"
  publish_github "$ver"
  publish_r2 "$ver"
  if [[ "${FORJA_SYNC_SKIP:-}" != "1" ]]; then
    sync_to_forjahq "$tag"
  else
    warn "Skipped mirror sync (${SYNC_REPO})"
  fi
  ok "Done: $tag"
}

cmd_bump() {
  local bump="${1:-patch}"
  case "$bump" in
    patch|minor|major) ;;
    *) die "bump must be patch, minor, or major" ;;
  esac
  require_cmd git
  require_publish_env
  if want_platform macos; then
    require_build_env
  fi

  require_clean_tree

  local ver
  ver="$(./scripts/bump_version.sh "$bump")"
  info "Bumped pubspec → $ver (platforms: $(platforms))"
  confirm "Freeze changelog, commit, tag v${ver}, push, then build + publish?" || {
    git checkout -- apps/forja/pubspec.yaml \
      apps/forja/lib/shared/services/app_version.dart \
      installer/windows/setup.iss \
      docs/backlog/README.md
    die "aborted (version files restored)"
  }

  ./scripts/changelog_freeze.sh "$ver"
  git add apps/forja/pubspec.yaml apps/forja/lib/shared/services/app_version.dart \
    installer/windows/setup.iss docs/changelog docs/backlog/README.md
  git commit -m "chore: release v${ver}"
  if git rev-parse "v${ver}" >/dev/null 2>&1; then
    die "Tag v${ver} already exists (often a stale tag from another era). Delete or retarget it, then re-run."
  fi
  git tag -a "v${ver}" -m "Forja ${ver}"
  git push origin HEAD
  git push origin "v${ver}"
  if [[ "${FORJA_SYNC_SKIP:-}" != "1" ]]; then
    sync_to_forjahq "v${ver}"
  else
    warn "Skipped mirror sync (${SYNC_REPO})"
  fi

  build_selected "$ver"
  publish_github "$ver"
  publish_r2 "$ver"
  ok "Done: v${ver}"
}

wizard_release_tag() {
  local tag detail rc do_sync=1
  while true; do
    pick_platforms || {
      rc=$?
      ((rc == 2)) && return 2
      ui_abort
    }
    tag="$(pick_tag_interactive)" || {
      rc=$?
      ((rc == 2)) && continue
      ui_abort
    }
    do_sync=1
    if ui_confirm_screen 3 5 "Sync to ${SYNC_REPO} after publish?" \
      "Pushes this branch + ${tag} from mGhassen/Forja → ${SYNC_REPO}." 1; then
      do_sync=1
    else
      rc=$?
      ((rc == 2)) && continue
      ((rc == 3)) && ui_abort
      do_sync=0
    fi
    detail="Tag:       ${tag}
Platforms: $(platforms)
Action:    build + publish → GitHub + R2
Mirror:    $([[ "$do_sync" == 1 ]] && echo "yes → ${SYNC_REPO}" || echo no)"
    if ui_confirm_screen 4 5 "Confirm release" "$detail" 1; then
      ui_raw_off
      ui_clear
      if ((do_sync)); then
        FORJA_SYNC_SKIP=0
      else
        FORJA_SYNC_SKIP=1
      fi
      export FORJA_SYNC_SKIP
      NONINTERACTIVE=1 cmd_tag "$tag"
      return 0
    else
      rc=$?
      ((rc == 2)) && continue
      ui_abort
    fi
  done
}

wizard_new_version() {
  local bump do_backfill=0 do_sync=1 detail rc
  # Fail before backfill/push so a dirty tree cannot strand a half-finished release.
  require_clean_tree
  while true; do
    pick_platforms || {
      rc=$?
      ((rc == 2)) && return 2
      ui_abort
    }
    bump="$(ui_choose 2 6 "Bump type" -- \
      "patch|patch — 1.2.N → 1.2.N+1" \
      "minor|minor — 1.2.x → 1.3.0" \
      "major|major — 1.x → 2.0.0")" || {
      rc=$?
      ((rc == 2)) && continue
      ui_abort
    }

    do_backfill=0
    if ui_confirm_screen 3 6 "Backfill untagged commits first?" \
      "Creates + pushes missing patch tags before the new release." 0; then
      do_backfill=1
    else
      rc=$?
      ((rc == 2)) && continue
      ((rc == 3)) && ui_abort
      do_backfill=0
    fi

    do_sync=1
    if ui_confirm_screen 4 6 "Sync to ${SYNC_REPO} after origin push?" \
      "Pushes this branch + new tag from mGhassen/Forja → ${SYNC_REPO}." 1; then
      do_sync=1
    else
      rc=$?
      ((rc == 2)) && continue
      ((rc == 3)) && ui_abort
      do_sync=0
    fi

    detail="Bump:      ${bump}
Platforms: $(platforms)
Backfill:  $([[ "$do_backfill" == 1 ]] && echo yes || echo no)
Mirror:    $([[ "$do_sync" == 1 ]] && echo "yes → ${SYNC_REPO}" || echo no)
Action:    freeze changelog → commit → tag → push → build + publish"
    if ui_confirm_screen 5 6 "Confirm new version" "$detail" 1; then
      :
    else
      rc=$?
      ((rc == 2)) && continue
      ui_abort
    fi

    ui_raw_off
    ui_clear
    if ((do_backfill)); then
      if ui_confirm_screen 6 6 "Dry-run backfill first?" "" 1; then
        cmd_backfill --dry-run
        ui_confirm_screen 6 6 "Looks good — run real backfill (push tags)?" "" 1 || ui_abort
      else
        rc=$?
        ((rc == 3)) && ui_abort
      fi
      ui_raw_off
      ui_clear
      cmd_backfill
      fetch_tags
      ok "backfill done — arc tip: $(default_release_tag)"
    fi
    if ((do_sync)); then
      FORJA_SYNC_SKIP=0
    else
      FORJA_SYNC_SKIP=1
    fi
    export FORJA_SYNC_SKIP
    NONINTERACTIVE=1 cmd_bump "$bump"
    return 0
  done
}

wizard_sync_menu() {
  local direction rc
  direction="$(ui_choose 1 2 "Sync with ${SYNC_REPO}" -- \
    "to|Sync to ${SYNC_REPO} — push branch + tag from origin" \
    "from|Sync from ${SYNC_REPO} — pull CI release commit → origin")" || {
    rc=$?
    ((rc == 2)) && return 2
    ui_abort
  }
  case "$direction" in
    to) wizard_sync ;;
    from) wizard_sync_from ;;
  esac
}

wizard_sync() {
  local tag detail branch
  fetch_tags
  tag="$(default_release_tag)"
  [[ -n "$tag" ]] || die "no v* tags found to sync"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  detail="Source:  origin ($(gh_repo))
Target:  ${SYNC_REPO}
Branch:  ${branch}
Tag:     ${tag}
Action:  force-push branch + tag (mGhassen overwrites ${SYNC_REPO})"
  if ui_confirm_screen 2 2 "Sync to ${SYNC_REPO}?" "$detail" 1; then
    ui_raw_off
    ui_clear
    NONINTERACTIVE=1 cmd_sync "$tag"
    return 0
  else
    local rc=$?
    ((rc == 2)) && return 2
    ui_abort
  fi
}

wizard_sync_from() {
  local tag detail branch remote_ref tip note=""
  require_clean_tree
  ensure_sync_remote
  git fetch "$SYNC_REMOTE" --tags --force
  branch="$(git rev-parse --abbrev-ref HEAD)"
  remote_ref="${SYNC_REMOTE}/${branch}"
  git rev-parse "$remote_ref" >/dev/null 2>&1 \
    || die "missing ${remote_ref} — does ${SYNC_REPO} have ${branch}?"
  tag="$(latest_pending_release_tag || true)"
  if [[ -z "$tag" ]]; then
    tag="$(latest_tag_on_ref "$remote_ref")" \
      || die "no v* tags found on ${remote_ref}"
  else
    note=" (pending — not on ${branch} yet)"
  fi
  tip="$(git rev-parse --short "${tag}^{commit}")"
  detail="Source:  ${SYNC_REPO}
Target:  origin ($(gh_repo))
Branch:  ${branch}
Tag:     ${tag} @ ${tip}${note}
Action:  FF or merge CI release commit, then push branch + tag to origin
Use after: Actions New version on forjahq"
  if ui_confirm_screen 2 2 "Sync from ${SYNC_REPO}?" "$detail" 1; then
    ui_raw_off
    ui_clear
    NONINTERACTIVE=1 cmd_sync_from "$tag"
    return 0
  else
    local rc=$?
    ((rc == 2)) && return 2
    ui_abort
  fi
}

wizard_backfill() {
  local mode rc
  mode="$(ui_choose 1 2 "Backfill untagged" -- \
    "dry|Dry-run only (no push)" \
    "real|Create and push tags")" || {
    rc=$?
    ((rc == 2)) && return 2
    ui_abort
  }
  ui_raw_off
  ui_clear
  if [[ "$mode" == dry ]]; then
    cmd_backfill --dry-run
  else
    ui_confirm_screen 2 2 "Create and push backfill tags?" "" 1 || ui_abort
    ui_raw_off
    ui_clear
    cmd_backfill
  fi
}

wizard_list_tags() {
  local filter
  filter="$(ui_input 1 1 "List tags" "Filter (empty = all)" "")" || ui_abort
  ui_clear
  echo
  echo "${C_BOLD}Release tags${C_RESET} ${C_DIM}(newest first)${C_RESET}"
  list_tags "$filter" || true
}

wizard_tools() {
  local tool tag rc gh_mode do_r2=0 do_sync=0
  tool="$(ui_choose 1 2 "Tools" -- \
    "build_macos|Build macOS DMG (host arch only)" \
    "build_windows|Build Windows (Parallels)" \
    "build_android_tv|Build Android TV APKs (per selected ABI)" \
    "publish|Publish dist/…" \
    "publish_r2|Upload dist/ → R2 only (retry)" \
    "setup_windows|Setup Windows VM")" || {
    rc=$?
    ((rc == 2)) && return 2
    ui_abort
  }
  case "$tool" in
    setup_windows)
      ui_raw_off
      ui_clear
      cmd_setup_windows
      ;;
    publish)
      tag="$(pick_tag_interactive)" || {
        rc=$?
        ((rc == 2)) && return 2
        ui_abort
      }
      gh_mode="$(ui_choose 2 5 "GitHub release" -- \
        "assets|Upload assets + update changelog notes" \
        "notes|Update changelog notes only (no assets)" \
        "skip|Skip GitHub")" || {
        rc=$?
        ((rc == 2)) && return 2
        ui_abort
      }
      if ui_confirm_screen 3 5 "Upload installers to R2?" \
        "Uses dist/ assets for ${tag}." 1; then
        do_r2=1
      else
        rc=$?
        ((rc == 2)) && return 2
        ((rc == 3)) && ui_abort
        do_r2=0
      fi
      if [[ "$gh_mode" == skip && "$do_r2" != "1" ]]; then
        ui_raw_off
        ui_clear
        die "nothing to publish — pick GitHub and/or R2"
      fi
      if ui_confirm_screen 4 5 "Also sync to ${SYNC_REPO} after publish?" \
        "Pushes this branch + tag → ${SYNC_REPO}." 1; then
        do_sync=1
      else
        rc=$?
        ((rc == 2)) && return 2
        ((rc == 3)) && ui_abort
        do_sync=0
      fi
      if ui_confirm_screen 5 5 "Confirm publish ${tag}" \
        "GitHub: ${gh_mode}
R2:      $([[ "$do_r2" == 1 ]] && echo yes || echo no)
Mirror:  $([[ "$do_sync" == 1 ]] && echo "yes → ${SYNC_REPO}" || echo no)" 1; then
        :
      else
        rc=$?
        ((rc == 2)) && return 2
        ui_abort
      fi
      ui_raw_off
      ui_clear
      cmd_publish_parts "$tag" "$gh_mode" "$do_r2" "$do_sync"
      ;;
    *)
      tag="$(pick_tag_interactive)" || ui_abort
      ui_raw_off
      ui_clear
      case "$tool" in
        build_macos) cmd_build "$tag" ;;
        build_windows) cmd_build_windows "$tag" ;;
        build_android_tv) cmd_build_android_tv "$tag" ;;
        publish_r2) cmd_publish_r2 "$tag" ;;
      esac
      ;;
  esac
}

interactive_menu() {
  fetch_tags

  if ! ui_can; then
    # Non-TTY fallback (piped / NONINTERACTIVE).
    local latest choice tag bump filter gh_mode do_r2 do_sync
    latest="$(default_release_tag)"
    echo
    echo "${C_BOLD}${C_CYAN}Forja local release${C_RESET}"
    hr
    echo "  ${C_DIM}latest tag${C_RESET}  ${latest:-none}"
    echo "  ${C_DIM}defaults${C_RESET}    $(platforms)"
    hr
    echo "  1) Existing tag"
    echo "  2) New version"
    echo "  3) Backfill"
    echo "  4) List tags"
    echo "  5) Build macOS"
    echo "  6) Build Windows"
    echo "  7) Build Android TV"
    echo "  8) Publish (GitHub + R2)"
    echo "  9) Upload R2 only"
    echo "  10) Sync → ${SYNC_REPO}"
    echo "  11) Sync ← ${SYNC_REPO} (CI release → origin)"
    echo "  12) Setup Windows VM"
    echo "  q) Quit"
    read -r -p "Choice: " choice
    case "$choice" in
      1)
        pick_platforms
        tag="$(pick_tag_interactive)"
        if confirm_yes "Also sync branch + tag to ${SYNC_REPO}?"; then
          FORJA_SYNC_SKIP=0
        else
          FORJA_SYNC_SKIP=1
        fi
        export FORJA_SYNC_SKIP
        cmd_tag "$tag"
        ;;
      2)
        pick_platforms
        bump="$(pick_bump)"
        if confirm_yes "Backfill untagged commits before releasing?"; then
          if confirm "Dry-run backfill first?"; then
            cmd_backfill --dry-run
            confirm_yes "Looks good — run real backfill (push tags)?" || die "aborted"
          fi
          cmd_backfill
          fetch_tags
        fi
        if confirm_yes "Also sync branch + tag to ${SYNC_REPO}?"; then
          FORJA_SYNC_SKIP=0
        else
          FORJA_SYNC_SKIP=1
        fi
        export FORJA_SYNC_SKIP
        cmd_bump "$bump"
        ;;
      3)
        if confirm "Dry-run only (no push)?"; then
          cmd_backfill --dry-run
        else
          confirm_yes "Create and push backfill tags?" || die "aborted"
          cmd_backfill
        fi
        ;;
      4)
        read -r -p "Filter (empty = all): " filter
        list_tags "$filter" || true
        ;;
      5) tag="$(pick_tag_interactive)"; cmd_build "$tag" ;;
      6) tag="$(pick_tag_interactive)"; cmd_build_windows "$tag" ;;
      7) tag="$(pick_tag_interactive)"; cmd_build_android_tv "$tag" ;;
      8)
        tag="$(pick_tag_interactive)"
        echo "GitHub: assets / notes / skip?"
        read -r -p "[assets|notes|skip] (default assets): " gh_mode
        gh_mode="${gh_mode:-assets}"
        if confirm_yes "Upload installers to R2?"; then do_r2=1; else do_r2=0; fi
        if confirm_yes "Also sync to ${SYNC_REPO}?"; then do_sync=1; else do_sync=0; fi
        cmd_publish_parts "$tag" "$gh_mode" "$do_r2" "$do_sync"
        ;;
      9) tag="$(pick_tag_interactive)"; cmd_publish_r2 "$tag" ;;
      10) cmd_sync ;;
      11) cmd_sync_from ;;
      12) cmd_setup_windows ;;
      q|Q) exit 0 ;;
      *) die "invalid choice" ;;
    esac
    return
  fi

  local action rc
  while true; do
    action="$(ui_choose 1 1 "What do you want to do?" -- \
      "release_tag|Release existing tag — platforms → build + publish" \
      "new_version|New version — bump → platforms → build + publish" \
      "sync|Sync with ${SYNC_REPO} — to / from origin…" \
      "backfill|Backfill untagged commits" \
      "list_tags|List / filter tags" \
      "tools|Build / publish tools…" \
      "quit|Quit")" || {
      rc=$?
      ((rc == 2 || rc == 3)) && { ui_raw_off; exit 0; }
      ui_abort
    }
    case "$action" in
      release_tag)
        wizard_release_tag || {
          rc=$?
          ((rc == 2)) && continue
          ui_abort
        }
        return
        ;;
      new_version)
        wizard_new_version || {
          rc=$?
          ((rc == 2)) && continue
          ui_abort
        }
        return
        ;;
      sync)
        wizard_sync_menu || {
          rc=$?
          ((rc == 2)) && continue
          ui_abort
        }
        return
        ;;
      backfill)
        wizard_backfill || {
          rc=$?
          ((rc == 2)) && continue
          ui_abort
        }
        return
        ;;
      list_tags) wizard_list_tags; return ;;
      tools)
        wizard_tools || {
          rc=$?
          ((rc == 2)) && continue
          ui_abort
        }
        return
        ;;
      quit) ui_raw_off; exit 0 ;;
    esac
  done
}

main() {
  load_env
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    "") interactive_menu ;;
    bump) cmd_bump "${1:-patch}" ;;
    tag) cmd_tag "${1:?usage: release_local.sh tag vX.Y.Z}" ;;
    backfill) cmd_backfill "${1:-}" ;;
    build) cmd_build "${1:?usage: release_local.sh build vX.Y.Z}" ;;
    build-windows) cmd_build_windows "${1:?usage: release_local.sh build-windows vX.Y.Z}" ;;
    build-android-tv) cmd_build_android_tv "${1:?usage: release_local.sh build-android-tv vX.Y.Z}" ;;
    setup-windows) cmd_setup_windows ;;
    publish) cmd_publish "${1:?usage: release_local.sh publish vX.Y.Z}" ;;
    publish-r2) cmd_publish_r2 "${1:?usage: release_local.sh publish-r2 vX.Y.Z}" ;;
    sync) cmd_sync "${1:-}" ;;
    sync-from) cmd_sync_from "${1:-}" ;;
    -h|--help)
      sed -n '3,35p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *)
      die "unknown command: $cmd (try --help)"
      ;;
  esac
}

main "$@"
