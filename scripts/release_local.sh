#!/usr/bin/env bash
set -euo pipefail

# Local macOS release → GitHub Release + Cloudflare R2 (no Actions artifacts).
#
# Usage:
#   ./scripts/release_local.sh                 # interactive menu
#   ./scripts/release_local.sh bump [patch|minor|major]
#   ./scripts/release_local.sh tag v1.2.404     # build + publish existing tag
#   ./scripts/release_local.sh build v1.2.404   # DMG only
#   ./scripts/release_local.sh publish v1.2.404 # upload dist/ → gh + R2
#
# Requires: macOS, Flutter, Rust, gh, repo .env (SUPABASE_*, RELEASE_CDN_URL,
# FORJA_WEB_URL, R2_*). Optional: TURNSTILE_SITE_KEY, SENTRY_DSN, POSTHOG_*.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_DIR="$ROOT/apps/forja"
DIST="$ROOT/dist"
# origin may not be gh's default when upstream also exists (PlayTorrio, etc.).
GH_REPO=""

die() { echo "error: $*" >&2; exit 1; }

# Resolve owner/name from git remote "origin" for all gh calls.
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
  [[ "$(uname -s)" == Darwin ]] || die "macOS build requires Darwin (got $(uname -s))"
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
  local tag="$1"
  echo "${tag#v}"
}

dmg_path() {
  local ver="$1"
  echo "$DIST/Forja-${ver}-macos-arm64.dmg"
}

confirm() {
  local prompt="${1:-Continue?}"
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
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

publish_github() {
  local ver="$1"
  local tag="v${ver}"
  local dmg notes repo
  dmg="$(dmg_path "$ver")"
  [[ -f "$dmg" ]] || die "missing $dmg — run build first"
  repo="$(gh_repo)"
  notes="$(mktemp)"
  ./scripts/changelog_release_notes.sh "$ver" "$notes"
  if gh_r release view "$tag" >/dev/null 2>&1; then
    echo "==> Updating GitHub release $tag ($repo)"
    if grep -q '^### ' "$notes"; then
      gh_r release edit "$tag" --title "Forja ${ver}" --notes-file "$notes"
    fi
    gh_r release upload "$tag" "$dmg" --clobber
  else
    echo "==> Creating GitHub release $tag ($repo)"
    local -a args=(
      "$tag"
      --title "Forja ${ver}"
      --verify-tag
      "$dmg"
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
}

publish_r2() {
  local ver="$1"
  local flat
  flat="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$flat'" RETURN
  mkdir -p "$flat"
  local f
  for f in "$DIST"/Forja-"${ver}"-macos-arm64.dmg \
           "$DIST"/Forja-"${ver}"-windows-setup.exe \
           "$DIST"/Forja-"${ver}"-linux-x86_64.AppImage \
           "$DIST"/Forja-"${ver}"-android-tv-*.apk; do
    [[ -e "$f" ]] || continue
    cp -f "$f" "$flat/"
  done
  if ! find "$flat" -type f | grep -q .; then
    die "no installers in dist/ for $ver"
  fi
  echo "==> Upload to R2"
  export R2_BUCKET="${R2_BUCKET:-forja-releases}"
  export RELEASE_STORAGE_KEEP="${RELEASE_STORAGE_KEEP:-3}"
  ./scripts/upload_release_to_r2.sh "$ver" "$flat"
}

cmd_build() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  echo "Build macOS DMG for $tag"
  build_macos "$ver"
}

cmd_publish() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  require_publish_env
  echo "Publish $tag → GitHub + R2"
  confirm "Upload $(dmg_path "$ver") to GitHub + R2?" || die "aborted"
  publish_github "$ver"
  publish_r2 "$ver"
  echo "Done: $tag"
}

cmd_tag() {
  local tag ver
  tag="$(normalize_tag "$1")"
  ver="$(version_from_tag "$tag")"
  require_publish_env
  echo "Local release $tag (build macOS → GitHub + R2)"
  confirm "Build and publish $tag?" || die "aborted"
  build_macos "$ver"
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
  require_build_env

  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree dirty — commit or stash first"
  fi

  local ver
  ver="$(./scripts/bump_version.sh "$bump")"
  echo "Bumped pubspec → $ver"
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

  build_macos "$ver"
  publish_github "$ver"
  publish_r2 "$ver"
  echo "Done: v${ver}"
}

interactive_menu() {
  echo "Forja local release (macOS → GitHub + R2)"
  echo "========================================="
  echo
  echo "  1) Release existing tag (build + publish)"
  echo "  2) Bump + release new version"
  echo "  3) Build DMG only"
  echo "  4) Publish dist/ only (gh + R2)"
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
    publish) cmd_publish "${1:?usage: release_local.sh publish vX.Y.Z}" ;;
    -h|--help)
      sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *)
      die "unknown command: $cmd (try --help)"
      ;;
  esac
}

main "$@"
