#!/usr/bin/env bash
set -euo pipefail

# Create a drag-to-Applications DMG from the release .app bundle.
# Usage: package_macos_dmg.sh <version> [arch]
#   arch: arm64 | x86_64 (default: host machine from uname -m)
# Output: dist/Forja-<version>-macos-<arch>.dmg

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: package_macos_dmg.sh <version> [arch]}"
APP="$ROOT/apps/forja"
APP_BUNDLE="$APP/build/macos/Build/Products/Release/forja.app"
DIST="$ROOT/dist"
STAGING="$DIST/dmg-staging"

normalize_arch() {
  case "$1" in
    arm64|aarch64) echo arm64 ;;
    x86_64|amd64|x64|i386) echo x86_64 ;;
    *)
      echo "error: unsupported macOS arch '$1' (want arm64 or x86_64)" >&2
      exit 1
      ;;
  esac
}

ARCH="$(normalize_arch "${2:-$(uname -m)}")"
DMG_NAME="Forja-${VERSION}-macos-${ARCH}.dmg"
DMG_PATH="$DIST/$DMG_NAME"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: missing $APP_BUNDLE — run flutter build macos --release first" >&2
  exit 1
fi

if [[ ! -f "$APP_BUNDLE/Contents/Frameworks/libffi.dylib" ]]; then
  echo "error: libffi.dylib not in app bundle" >&2
  exit 1
fi

EXE="$APP_BUNDLE/Contents/MacOS/forja"
if [[ ! -f "$EXE" ]]; then
  echo "error: missing executable $EXE" >&2
  exit 1
fi

# Refuse packaging a host-mismatched binary (e.g. arm64 app labeled x86_64).
if command -v lipo >/dev/null 2>&1; then
  arches="$(lipo -archs "$EXE" 2>/dev/null || true)"
  if [[ -n "$arches" ]]; then
    case " $arches " in
      *" $ARCH "*) ;;
      *)
        echo "error: $EXE arches [$arches] do not include expected $ARCH" >&2
        exit 1
        ;;
    esac
  fi
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
