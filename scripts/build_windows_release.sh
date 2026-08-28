#!/usr/bin/env bash
set -euo pipefail

# Build Forja Windows installer (same steps as .github/workflows/release.yml).
# Run inside Windows (Git Bash / MSYS) with Flutter + Rust + Inno Setup installed.
#
# Usage:
#   ./scripts/build_windows_release.sh <version>
#   ./scripts/build_windows_release.sh 1.2.403
#
# Reads dart-defines from the environment (load .env first). Output:
#   dist/Forja-<version>-windows-setup.exe
#   installer/windows/Output/Forja-<version>-windows-setup.exe

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${1:?usage: build_windows_release.sh <version>}"
VERSION="${VERSION#v}"
APP_DIR="$ROOT/apps/forja"
DIST="$ROOT/dist"
OUT_NAME="Forja-${VERSION}-windows-setup"
ISCC="${ISCC:-/c/Program Files (x86)/Inno Setup 6/ISCC.exe}"
# Windows-native path for ISCC when running under Git Bash
ISCC_WIN='C:\Program Files (x86)\Inno Setup 6\ISCC.exe'

die() { echo "error: $*" >&2; exit 1; }

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *)
    # Allow WSL only if flutter windows is somehow available — usually not.
    die "run this script inside Windows Git Bash (not macOS/Linux). Got: $(uname -s)"
    ;;
esac

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -z "${SUPABASE_PUBLISHABLE_KEY:-}" && -n "${SUPABASE_ANON_KEY:-}" ]]; then
  SUPABASE_PUBLISHABLE_KEY="$SUPABASE_ANON_KEY"
fi

[[ -n "${SUPABASE_URL:-}" ]] || die "SUPABASE_URL missing"
[[ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]] || die "SUPABASE_PUBLISHABLE_KEY missing"
[[ -n "${RELEASE_CDN_URL:-}" ]] || die "RELEASE_CDN_URL missing"
[[ -n "${FORJA_WEB_URL:-}" ]] || die "FORJA_WEB_URL missing"
[[ -n "${FORJA_HQ_PROVIDERS_MANIFEST_URL:-}" && -n "${FORJA_HQ_LIVE_MANIFEST_URL:-}" && -n "${FORJA_HQ_CATALOG_MANIFEST_URL:-}" ]] || die "FORJA_HQ_PROVIDERS/LIVE/CATALOG_MANIFEST_URL missing"

command -v flutter >/dev/null || die "flutter not on PATH"
command -v cargo >/dev/null || die "cargo/rust not on PATH"

echo "==> Rust FFI"
./scripts/build_rust_release.sh

echo "==> Flutter Windows ($VERSION)"
(
  cd "$APP_DIR"
  flutter pub get
  flutter build windows --release \
    --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
    --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
    --dart-define=RELEASE_CDN_URL="${RELEASE_CDN_URL}" \
    --dart-define=FORJA_WEB_URL="${FORJA_WEB_URL}" \
    --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}" \
    --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
    --dart-define=POSTHOG_API_KEY="${POSTHOG_API_KEY:-}" \
    --dart-define=POSTHOG_HOST="${POSTHOG_HOST:-}" \
    --dart-define=SIMKL_CLIENT_ID="${SIMKL_CLIENT_ID:-}" \
    --dart-define=FORJA_HQ_PROVIDERS_MANIFEST_URL="${FORJA_HQ_PROVIDERS_MANIFEST_URL}" --dart-define=FORJA_HQ_LIVE_MANIFEST_URL="${FORJA_HQ_LIVE_MANIFEST_URL}" --dart-define=FORJA_HQ_CATALOG_MANIFEST_URL="${FORJA_HQ_CATALOG_MANIFEST_URL}"
)

echo "==> Embed Rust + MSVC CRT + verify"
./scripts/embed_rust_in_release_output.sh windows
./scripts/bundle_windows_msvc_crt.sh
./scripts/verify_installer_payload.sh windows

echo "==> Inno Setup"
if [[ -x "$ISCC" ]]; then
  "$ISCC" \
    "/DMyAppVersion=${VERSION}" \
    "/DMyOutputBaseFilename=${OUT_NAME}" \
    "installer/windows/setup.iss"
elif [[ -f "$ISCC_WIN" ]] || cmd.exe /c "if exist \"$ISCC_WIN\" exit 0" >/dev/null 2>&1; then
  # Call via cmd so paths with spaces work from Git Bash
  cmd.exe /c "\"${ISCC_WIN}\" /DMyAppVersion=${VERSION} /DMyOutputBaseFilename=${OUT_NAME} installer\\windows\\setup.iss"
else
  die "Inno Setup ISCC.exe not found (install via scripts/setup_windows_vm.ps1)"
fi

EXE_SRC="$ROOT/installer/windows/Output/${OUT_NAME}.exe"
[[ -f "$EXE_SRC" ]] || die "missing installer: $EXE_SRC"
mkdir -p "$DIST"
cp -f "$EXE_SRC" "$DIST/${OUT_NAME}.exe"
ls -lh "$DIST/${OUT_NAME}.exe"
echo "Created $DIST/${OUT_NAME}.exe"
