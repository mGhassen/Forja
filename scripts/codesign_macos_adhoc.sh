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

# Deep ad-hoc sign, no entitlements plist.
codesign --force --deep --sign - "$APP_BUNDLE"

# Flutter universal bundles sometimes trip --strict Info.plist binding on the
# main executable; launch still works. Warn instead of failing the release.
if ! codesign --verify --deep "$APP_BUNDLE" 2>/tmp/forja-codesign-verify.err; then
  echo "warning: codesign --verify reported issues (often Info.plist binding on universal binary):" >&2
  cat /tmp/forja-codesign-verify.err >&2 || true
fi

echo "Ad-hoc signed: $APP_BUNDLE"
