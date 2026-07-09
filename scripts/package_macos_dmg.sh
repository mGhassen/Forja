#!/usr/bin/env bash
set -euo pipefail

# Create a drag-to-Applications DMG from the release .app bundle.
# Usage: package_macos_dmg.sh <version>
# Output: dist/Forja-<version>-macos-arm64.dmg

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: package_macos_dmg.sh <version>}"
APP="$ROOT/apps/forja"
APP_BUNDLE="$APP/build/macos/Build/Products/Release/forja.app"
DIST="$ROOT/dist"
STAGING="$DIST/dmg-staging"
DMG_NAME="Forja-${VERSION}-macos-arm64.dmg"
DMG_PATH="$DIST/$DMG_NAME"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: missing $APP_BUNDLE — run flutter build macos --release first" >&2
  exit 1
fi

if [[ ! -f "$APP_BUNDLE/Contents/Frameworks/libffi.dylib" ]]; then
  echo "error: libffi.dylib not in app bundle" >&2
  exit 1
fi

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING" "$DIST"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Forja $VERSION" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING"
echo "Created $DMG_PATH"
