#!/usr/bin/env bash
set -euo pipefail

# Ad-hoc codesign a macOS .app so dyld will load embedded frameworks.
# No Apple Developer cert / notarization. Does not embed entitlements
# (App Sandbox + ad-hoc → Launch Services kLSNoExecutableErr).
#
# Usage: codesign_macos_adhoc.sh [path-to.app]
# Default: apps/forja/build/macos/Build/Products/Release/forja.app

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="${1:-$ROOT/apps/forja/build/macos/Build/Products/Release/forja.app}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  ALT="$ROOT/apps/forja/build/macos/Build/Products/Release/Forja.app"
  if [[ -d "$ALT" ]]; then
    APP_BUNDLE="$ALT"
  else
    echo "error: missing app bundle at $APP_BUNDLE" >&2
    exit 1
  fi
fi

# Drop quarantine / finder metadata that can confuse codesign after copies.
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

FRAMEWORKS="$APP_BUNDLE/Contents/Frameworks"
if [[ -d "$FRAMEWORKS" ]]; then
  # media_kit XCFrameworks ship unsigned; sign leaf binaries before --deep.
  while IFS= read -r -d '' bin; do
    codesign --force --sign - --timestamp=none "$bin" 2>/dev/null || true
  done < <(find "$FRAMEWORKS" -type f -path "*.framework/Versions/*/*" ! -path "*/Resources/*" -print0)
  while IFS= read -r -d '' fw; do
    codesign --force --sign - --timestamp=none "$fw" 2>/dev/null || true
  done < <(find "$FRAMEWORKS" -maxdepth 1 -name "*.framework" -type d -print0)
  while IFS= read -r -d '' lib; do
    codesign --force --sign - --timestamp=none "$lib" 2>/dev/null || true
  done < <(find "$FRAMEWORKS" -maxdepth 1 \( -name "*.dylib" -o -name "*.so" \) -type f -print0)
fi

# Deep ad-hoc sign, no entitlements plist.
codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"

# Flutter universal bundles sometimes trip --strict Info.plist binding on the
# main executable; launch still works. Warn instead of failing the release.
if ! codesign --verify --deep "$APP_BUNDLE" 2>/tmp/forja-codesign-verify.err; then
  echo "warning: codesign --verify reported issues (often Info.plist binding on universal binary):" >&2
  cat /tmp/forja-codesign-verify.err >&2 || true
fi

echo "Ad-hoc signed: $APP_BUNDLE"
