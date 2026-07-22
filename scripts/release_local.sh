#!/usr/bin/env bash
set -euo pipefail

# Local release → GitHub Release + Cloudflare R2 (no Actions artifacts).
#
# Usage:
#   ./scripts/release_local.sh                      # interactive menu
#   ./scripts/release_local.sh bump [patch|minor|major]
#   ./scripts/release_local.sh tag v1.2.404          # macOS (+ Windows via Parallels if set)
#   ./scripts/release_local.sh build v1.2.404        # macOS DMG only
#   ./scripts/release_local.sh build-windows v1.2.404  # Windows via Parallels VM
#   ./scripts/release_local.sh setup-windows         # print / run VM toolchain setup
#   ./scripts/release_local.sh publish v1.2.404      # upload dist/ → gh + R2
#
# Env:
#   FORJA_PRL_VM=Windows 11          Parallels VM name (enables Windows build)
#   FORJA_WIN_REPO=\\Mac\Forja       Windows path to this repo (default share name Forja)
#   FORJA_PLATFORMS=macos,windows    platforms for tag/bump (default: macos; +windows if VM set)
#   NONINTERACTIVE=1                 skip confirm prompts
#
# Requires (.env): SUPABASE_*, RELEASE_CDN_URL, FORJA_WEB_URL, R2_*
# Optional: TURNSTILE_SITE_KEY, SENTRY_DSN, POSTHOG_*

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_DIR="$ROOT/apps/forja"
DIST="$ROOT/dist"
GH_REPO=""
PRL_VM="${FORJA_PRL_VM:-Windows 11}"

die() { echo "error: $*" >&2; exit 1; }

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
  read -r -p "$prompt [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Platforms for tag/bump: comma list macos,windows
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
  if want_platform macos; then
    build_macos "$ver"
  fi
  if want_platform windows; then
    build_windows_prl "$ver"
  fi
}

cmd_build() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  echo "Build macOS DMG for $tag"
  build_macos "$ver"
}

cmd_build_windows() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  echo "Build Windows installer for $tag via Parallels ($PRL_VM)"
  confirm "Start Windows build in VM?" || die "aborted"
  build_windows_prl "$ver"
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
  echo "Publish $tag → GitHub + R2"
  collect_assets "$ver" >/dev/null
  confirm "Upload dist assets for $ver to GitHub + R2?" || die "aborted"
  publish_github "$ver"
  publish_r2 "$ver"
  echo "Done: $tag"
}

cmd_tag() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  require_publish_env
  echo "Local release $tag (platforms: $(platforms))"
  confirm "Build and publish $tag?" || die "aborted"
  build_selected "$ver"
  publish_github "$ver"
  publish_r2 "$ver"
  echo "Done: $tag"
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
  echo "Bumped pubspec → $ver (platforms: $(platforms))"
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
  echo "Done: v${ver}"
}

interactive_menu() {
  echo "Forja local release (GitHub + R2)"
  echo "================================="
  echo "Platforms: $(platforms)   VM: $PRL_VM"
  echo
  echo "  1) Release existing tag (build + publish)"
  echo "  2) Bump + release new version"
  echo "  3) Build macOS DMG only"
  echo "  4) Build Windows via Parallels"
  echo "  5) Setup Windows VM toolchain"
  echo "  6) Publish dist/ only (gh + R2)"
  echo "  q) Quit"
  echo
  read -r -p "Choice: " choice
  case "$choice" in
    1)
      read -r -p "Tag (e.g. v1.2.404): " tag
      cmd_tag "$tag"
      ;;
    2)
      echo "Bump: 1=patch 2=minor 3=major"
      read -r -p "Choice [1]: " bump_choice
      case "${bump_choice:-1}" in
        1) cmd_bump patch ;;
        2) cmd_bump minor ;;
        3) cmd_bump major ;;
        *) die "invalid" ;;
      esac
      ;;
    3)
      read -r -p "Tag (e.g. v1.2.404): " tag
      cmd_build "$tag"
      ;;
    4)
      read -r -p "Tag (e.g. v1.2.404): " tag
      cmd_build_windows "$tag"
      ;;
    5) cmd_setup_windows ;;
    6)
      read -r -p "Tag (e.g. v1.2.404): " tag
      cmd_publish "$tag"
      ;;
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
    build) cmd_build "${1:?usage: release_local.sh build vX.Y.Z}" ;;
    build-windows) cmd_build_windows "${1:?usage: release_local.sh build-windows vX.Y.Z}" ;;
    setup-windows) cmd_setup_windows ;;
    publish) cmd_publish "${1:?usage: release_local.sh publish vX.Y.Z}" ;;
    -h|--help)
      sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *)
      die "unknown command: $cmd (try --help)"
      ;;
  esac
}

main "$@"
