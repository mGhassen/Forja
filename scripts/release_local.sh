#!/usr/bin/env bash
set -euo pipefail

# Local release → GitHub Release + Cloudflare R2 (no Actions artifacts).
#
# Usage:
#   ./scripts/release_local.sh                         # interactive menu
#   ./scripts/release_local.sh bump [patch|minor|major]
#   ./scripts/release_local.sh tag v1.2.404             # build + publish selected platforms
#   ./scripts/release_local.sh backfill [--dry-run]     # tag untagged commits (push)
#   ./scripts/release_local.sh build v1.2.404           # macOS DMG only
#   ./scripts/release_local.sh build-android-tv v1.2.404  # Android TV APKs (arm64 + v7a)
#   ./scripts/release_local.sh build-windows v1.2.404   # Windows via Parallels VM
#   ./scripts/release_local.sh setup-windows            # print / run VM toolchain setup
#   ./scripts/release_local.sh publish v1.2.404         # upload dist/ → gh + R2
#
# Env:
#   FORJA_PRL_VM=Windows 11          Parallels VM name (enables Windows build)
#   FORJA_WIN_REPO=\\Mac\Forja       Windows path to this repo (default share name Forja)
#   FORJA_PLATFORMS=macos,windows,android_tv
#                                    platforms for tag/bump (interactive pick if unset;
#                                    default: macos; +windows if VM set)
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

if [[ -t 1 ]]; then
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_RESET=$'\033[0m'
else
  C_BOLD="" C_DIM="" C_CYAN="" C_GREEN="" C_YELLOW="" C_RED="" C_RESET=""
fi

die() { echo "${C_RED}error:${C_RESET} $*" >&2; exit 1; }

info() { echo "${C_CYAN}==>${C_RESET} $*"; }
ok() { echo "${C_GREEN}✓${C_RESET} $*"; }
warn() { echo "${C_YELLOW}!${C_RESET} $*"; }

hr() { echo "${C_DIM}────────────────────────────────────────${C_RESET}"; }

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

dmg_path() { echo "$DIST/Forja-${1}-macos-arm64.dmg"; }
exe_path() { echo "$DIST/Forja-${1}-windows-setup.exe"; }

confirm() {
  local prompt="${1:-Continue?}"
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    return 0
  fi
  read -r -p "${C_BOLD}${prompt}${C_RESET} [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Default yes (Enter accepts).
confirm_yes() {
  local prompt="${1:-Continue?}"
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    return 0
  fi
  read -r -p "${C_BOLD}${prompt}${C_RESET} [Y/n]: " ans
  [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]
}

fetch_tags() {
  git fetch origin --tags --force 2>/dev/null || true
}

latest_tag() {
  git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -1
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
  fetch_tags
  local filter picked tags tag
  echo
  read -r -p "Filter tags (empty = all, e.g. 1.2): " filter
  tags="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname)"
  if [[ -n "$filter" ]]; then
    tags="$(grep -i "$filter" <<<"$tags" || true)"
  fi
  [[ -n "$tags" ]] || die "no tags match"
  echo
  local i=1
  while IFS= read -r t; do
    printf "  ${C_DIM}%2d)${C_RESET} %s\n" "$i" "$t"
    i=$((i + 1))
  done <<<"$tags"
  echo
  read -r -p "Pick number or type tag: " picked
  [[ -n "$picked" ]] || die "empty tag"
  if [[ "$picked" =~ ^[0-9]+$ ]]; then
    tag="$(sed -n "${picked}p" <<<"$tags")"
    [[ -n "$tag" ]] || die "invalid number"
  else
    tag="$(normalize_tag "$picked")"
  fi
  echo "$tag"
}

pick_bump() {
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    echo "${1:-patch}"
    return
  fi
  echo
  echo "Bump type:"
  echo "  ${C_DIM}1)${C_RESET} patch   ${C_DIM}(default)${C_RESET}"
  echo "  ${C_DIM}2)${C_RESET} minor"
  echo "  ${C_DIM}3)${C_RESET} major"
  read -r -p "Choice [1]: " bump_choice
  case "${bump_choice:-1}" in
    1|patch) echo patch ;;
    2|minor) echo minor ;;
    3|major) echo major ;;
    *) die "invalid bump" ;;
  esac
}

# Platforms for tag/bump: comma list macos,windows,linux,android_tv
platforms() {
  if [[ -n "${FORJA_PLATFORMS:-}" ]]; then
    echo "$FORJA_PLATFORMS"
    return
  fi
  if command -v prlctl >/dev/null 2>&1 && prlctl list -a 2>/dev/null | grep -q "$PRL_VM"; then
    echo "macos,windows"
  else
    echo "macos"
  fi
}

want_platform() {
  local p="$1"
  [[ ",$(platforms)," == *",$p,"* ]]
}

# Interactive Y/n prompts → FORJA_PLATFORMS (same surface as release_ci.sh / Actions).
pick_platforms() {
  if [[ -n "${FORJA_PLATFORMS:-}" || "${NONINTERACTIVE:-}" == "1" ]]; then
    return
  fi

  local macos=true windows=false linux=false android_tv=false
  if command -v prlctl >/dev/null 2>&1 && prlctl list -a 2>/dev/null | grep -q "$PRL_VM"; then
    windows=true
  fi

  echo
  echo "${C_BOLD}Platforms${C_RESET} ${C_DIM}(Enter = keep default)${C_RESET}"
  read -r -p "  macOS [Y/n]: " ans
  [[ "$ans" =~ ^[Nn]$ ]] && macos=false

  if $windows; then
    read -r -p "  Windows [Y/n]: " ans
    [[ "$ans" =~ ^[Nn]$ ]] && windows=false
  else
    read -r -p "  Windows [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && windows=true
  fi

  read -r -p "  Linux [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]] && linux=true

  read -r -p "  Android TV [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]] && android_tv=true

  local -a selected=()
  $macos && selected+=(macos)
  $windows && selected+=(windows)
  $linux && selected+=(linux)
  $android_tv && selected+=(android_tv)
  ((${#selected[@]} > 0)) || die "select at least one platform"

  FORJA_PLATFORMS="$(IFS=,; echo "${selected[*]}")"
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
  require_build_env
  echo "==> Rust FFI"
  ./scripts/build_rust_release.sh
  echo "==> Flutter macOS ($ver)"
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
  echo "==> Package DMG"
  ./scripts/package_macos_dmg.sh "$ver"
  local dmg
  dmg="$(dmg_path "$ver")"
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
  local keystore="" tmp_ks="" key_alias
  require_cmd flutter
  require_cmd keytool
  [[ -n "${SUPABASE_URL:-}" ]] || die "SUPABASE_URL missing (set in .env)"
  [[ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]] || die "SUPABASE_PUBLISHABLE_KEY missing (set in .env)"
  [[ -n "${RELEASE_CDN_URL:-}" ]] || die "RELEASE_CDN_URL missing (set in .env)"
  [[ -n "${FORJA_WEB_URL:-}" ]] || die "FORJA_WEB_URL missing (set in .env)"
  [[ -n "${FORJA_KEYSTORE_PASSWORD:-}" ]] || die "FORJA_KEYSTORE_PASSWORD missing (set in .env)"
  [[ -n "${FORJA_KEY_PASSWORD:-}" ]] || die "FORJA_KEY_PASSWORD missing (set in .env)"

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

  info "Flutter Android TV APKs ($ver) — arm64 + armeabi-v7a"
  (
    cd "$APP_DIR"
    flutter pub get
    flutter build apk --release --split-per-abi \
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
  ./scripts/package_android_tv_apk.sh "$ver"
  ls -lh "$DIST/Forja-${ver}-android-tv-arm64.apk" \
    "$DIST/Forja-${ver}-android-tv-armeabi-v7a.apk"
}

collect_assets() {
  local ver="$1"
  local -a files=()
  local f
  for f in "$(dmg_path "$ver")" \
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
  local ver="$1"
  local tag="v${ver}"
  local notes repo
  local -a assets=()
  mapfile -t assets < <(collect_assets "$ver")
  repo="$(gh_repo)"
  notes="$(mktemp)"
  ./scripts/changelog_release_notes.sh "$ver" "$notes"
  if gh_r release view "$tag" >/dev/null 2>&1; then
    echo "==> Updating GitHub release $tag ($repo)"
    if grep -q '^### ' "$notes"; then
      gh_r release edit "$tag" --title "Forja ${ver}" --notes-file "$notes"
    fi
    gh_r release upload "$tag" "${assets[@]}" --clobber
  else
    echo "==> Creating GitHub release $tag ($repo)"
    local -a args=(
      "$tag"
      --title "Forja ${ver}"
      --verify-tag
      "${assets[@]}"
    )
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
  printf '  asset: %s\n' "${assets[@]}"
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
  if want_platform linux; then
    [[ "$(uname -s)" == Linux ]] \
      || die "Linux AppImage builds need a Linux host — use ./scripts/release_ci.sh"
    die "local Linux AppImage build not wired — use ./scripts/release_ci.sh"
  fi
  if want_platform macos; then
    build_macos "$ver"
  fi
  if want_platform windows; then
    build_windows_prl "$ver"
  fi
  if want_platform android_tv; then
    build_android_tv "$ver"
  fi
}

cmd_build() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  info "Build macOS DMG for $tag"
  build_macos "$ver"
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
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  info "Build Android TV APKs for $tag (arm64 + armeabi-v7a)"
  confirm "Start Android TV release build?" || die "aborted"
  build_android_tv "$ver"
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
  publish_github "$ver"
  publish_r2 "$ver"
  ok "Done: $tag"
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

  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree dirty — commit or stash first"
  fi

  local ver
  ver="$(./scripts/bump_version.sh "$bump")"
  info "Bumped pubspec → $ver (platforms: $(platforms))"
  confirm "Freeze changelog, commit, tag v${ver}, push, then build + publish?" || {
    git checkout -- apps/forja/pubspec.yaml installer/windows/setup.iss
    die "aborted (pubspec restored)"
  }

  ./scripts/changelog_freeze.sh "$ver"
  git add apps/forja/pubspec.yaml installer/windows/setup.iss docs/changelog
  git commit -m "chore: release v${ver}"
  git tag -a "v${ver}" -m "Forja ${ver}"
  git push origin HEAD
  git push origin "v${ver}"

  build_selected "$ver"
  publish_github "$ver"
  publish_r2 "$ver"
  ok "Done: v${ver}"
}

interactive_menu() {
  local latest choice tag bump
  fetch_tags
  latest="$(latest_tag)"

  echo
  echo "${C_BOLD}${C_CYAN}Forja local release${C_RESET}"
  hr
  echo "  ${C_DIM}latest tag${C_RESET}  ${latest:-none}"
  echo "  ${C_DIM}defaults${C_RESET}    $(platforms)"
  echo "  ${C_DIM}toggles${C_RESET}     macOS · Windows · Linux · Android TV"
  echo "  ${C_DIM}windows VM${C_RESET}  $PRL_VM"
  hr
  echo
  echo "  ${C_BOLD}Release${C_RESET}"
  echo "  ${C_DIM}1)${C_RESET} Existing tag          pick platforms → build + publish"
  echo "  ${C_DIM}2)${C_RESET} New version           backfill? → bump → platforms → build + publish"
  echo
  echo "  ${C_BOLD}Tags${C_RESET}"
  echo "  ${C_DIM}3)${C_RESET} Backfill untagged     create + push patch tags"
  echo "  ${C_DIM}4)${C_RESET} List / filter tags"
  echo
  echo "  ${C_BOLD}Tools${C_RESET}"
  echo "  ${C_DIM}5)${C_RESET} Build macOS DMG only"
  echo "  ${C_DIM}6)${C_RESET} Build Windows (Parallels)"
  echo "  ${C_DIM}7)${C_RESET} Build Android TV APKs"
  echo "  ${C_DIM}8)${C_RESET} Publish dist/ only"
  echo "  ${C_DIM}9)${C_RESET} Setup Windows VM"
  echo "  ${C_DIM}q)${C_RESET} Quit"
  echo
  read -r -p "${C_BOLD}Choice:${C_RESET} " choice

  case "$choice" in
    1)
      pick_platforms
      tag="$(pick_tag_interactive)"
      cmd_tag "$tag"
      ;;
    2)
      pick_platforms
      bump="$(pick_bump)"
      echo
      if confirm_yes "Backfill untagged commits before releasing?"; then
        if confirm "Dry-run backfill first?"; then
          cmd_backfill --dry-run
          confirm_yes "Looks good — run real backfill (push tags)?" || die "aborted"
        fi
        cmd_backfill
        fetch_tags
        ok "backfill done — latest tag: $(latest_tag)"
      else
        warn "skipping backfill"
      fi
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
      echo
      echo "${C_BOLD}Release tags${C_RESET} ${C_DIM}(newest first)${C_RESET}"
      list_tags "$filter" || true
      ;;
    5)
      tag="$(pick_tag_interactive)"
      cmd_build "$tag"
      ;;
    6)
      tag="$(pick_tag_interactive)"
      cmd_build_windows "$tag"
      ;;
    7)
      tag="$(pick_tag_interactive)"
      cmd_build_android_tv "$tag"
      ;;
    8)
      tag="$(pick_tag_interactive)"
      cmd_publish "$tag"
      ;;
    9) cmd_setup_windows ;;
    q|Q) exit 0 ;;
    *) die "invalid choice" ;;
  esac
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
    -h|--help)
      sed -n '3,27p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *)
      die "unknown command: $cmd (try --help)"
      ;;
  esac
}

main "$@"
