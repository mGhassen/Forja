#!/usr/bin/env bash
set -euo pipefail

# Create a drag-to-Applications DMG (large icons, matrix-style light background).
# Usage: package_macos_dmg.sh <version> [arch]
#   arch: arm64 | x86_64 (default: host machine from uname -m)
# Output: dist/Forja-<version>-macos-<arch>.dmg

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: package_macos_dmg.sh <version> [arch]}"
APP="$ROOT/apps/forja"
RELEASE_DIR="$APP/build/macos/Build/Products/Release"
BACKGROUND="$ROOT/scripts/dmg/background.png"
DIST="$ROOT/dist"
STAGING="$DIST/dmg-staging"
RW_DMG="$DIST/dmg-rw-$$.dmg"
MOUNT_ROOT="/Volumes"
VOLNAME="Forja"
APP_NAME="Forja.app"

# Finder window (points). Background PNG is 2× (1320×800) for Retina.
WIN_W=660
WIN_H=400
ICON_SIZE=128
ICON_APP_X=180
ICON_APP_Y=190
ICON_APPS_X=480
ICON_APPS_Y=190

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

resolve_app_bundle() {
  if [[ -d "$RELEASE_DIR/Forja.app" ]]; then
    echo "$RELEASE_DIR/Forja.app"
  elif [[ -d "$RELEASE_DIR/forja.app" ]]; then
    echo "$RELEASE_DIR/forja.app"
  else
    echo ""
  fi
}

detach_volume() {
  local vol="$1"
  local i
  for i in 1 2 3 4 5; do
    if hdiutil detach "$vol" -quiet 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  hdiutil detach "$vol" -force -quiet 2>/dev/null || true
}

# Wait until the RW image is no longer attached (detach can race DiskImages).
wait_image_free() {
  local image="$1"
  local i
  for i in 1 2 3 4 5 6 7 8; do
    if ! hdiutil info 2>/dev/null | grep -F "$image" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  # Last resort: force-detach any mount of this image.
  local dev
  dev="$(hdiutil info 2>/dev/null | awk -v img="$image" '
    $0 ~ /^image-path/ { keep = index($0, img) > 0 }
    keep && /^\/dev\// { print $1; exit }
  ')"
  if [[ -n "$dev" ]]; then
    hdiutil detach "$dev" -force -quiet 2>/dev/null || true
    sleep 1
  fi
}

convert_udzo() {
  local src="$1"
  local dst="$2"
  local i
  local err
  for i in 1 2 3 4 5 6; do
    err="$(mktemp -t dmg-convert)"
    if hdiutil convert "$src" -format UDZO -imagekey zlib-level=9 -o "$dst" 2>"$err"; then
      rm -f "$err"
      return 0
    fi
    # Common flaky macOS failure when DiskImages is busy / image still settling.
    if grep -qiE 'Resource temporarily unavailable|Resource busy|Device busy' "$err"; then
      echo "warning: hdiutil convert attempt $i failed (busy); retrying…" >&2
      cat "$err" >&2 || true
      rm -f "$err" "$dst"
      wait_image_free "$src"
      sleep $((i * 2))
      continue
    fi
    cat "$err" >&2 || true
    rm -f "$err"
    return 1
  done
  echo "error: hdiutil convert failed after retries (often too many mounted DMGs — eject old Forja volumes)" >&2
  return 1
}

ARCH="$(normalize_arch "${2:-$(uname -m)}")"
DMG_NAME="Forja-${VERSION}-macos-${ARCH}.dmg"
DMG_PATH="$DIST/$DMG_NAME"
APP_BUNDLE="$(resolve_app_bundle)"

if [[ -z "$APP_BUNDLE" ]]; then
  echo "error: missing Forja.app under $RELEASE_DIR — run flutter build macos --release first" >&2
  exit 1
fi

if [[ ! -f "$BACKGROUND" ]]; then
  echo "error: missing DMG background $BACKGROUND" >&2
  exit 1
fi

if [[ ! -f "$APP_BUNDLE/Contents/Frameworks/libffi.dylib" ]]; then
  echo "error: libffi.dylib not in app bundle" >&2
  exit 1
fi

EXE=""
for candidate in Forja forja; do
  if [[ -f "$APP_BUNDLE/Contents/MacOS/$candidate" ]]; then
    EXE="$APP_BUNDLE/Contents/MacOS/$candidate"
    break
  fi
done
if [[ -z "$EXE" ]]; then
  echo "error: missing executable under $APP_BUNDLE/Contents/MacOS/" >&2
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

cleanup() {
  if [[ -n "${VOLUME:-}" && -d "$VOLUME" ]]; then
    detach_volume "$VOLUME" || true
  fi
  rm -rf "$STAGING"
  rm -f "$RW_DMG"
}
trap cleanup EXIT

rm -rf "$STAGING" "$DMG_PATH" "$RW_DMG"
mkdir -p "$STAGING/.background" "$DIST"

cp -R "$APP_BUNDLE" "$STAGING/$APP_NAME"
ln -s /Applications "$STAGING/Applications"
cp "$BACKGROUND" "$STAGING/.background/background.png"

# Writable image so Finder can write .DS_Store (icon layout + background).
hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG"

# Mount read-write; resolve the volume path Finder will use.
ATTACH_OUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(echo "$ATTACH_OUT" | awk 'NR==1 {print $1}')"
VOLUME="$MOUNT_ROOT/$VOLNAME"
if [[ ! -d "$VOLUME" ]]; then
  # Rare: volume name collision — pick the mount point from attach output.
  VOLUME="$(echo "$ATTACH_OUT" | awk '/\/Volumes\// {print $3; exit}')"
fi
if [[ ! -d "$VOLUME" ]]; then
  echo "error: failed to mount $RW_DMG" >&2
  echo "$ATTACH_OUT" >&2
  exit 1
fi

# Bless Finder window: matrix bg, large icons, app → Applications.
# Retries absorb Finder flakiness on CI runners.
configure_finder() {
  osascript <<EOF
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, $((200 + WIN_W)), $((120 + WIN_H))}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $ICON_SIZE
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$APP_NAME" to {$ICON_APP_X, $ICON_APP_Y}
    set position of item "Applications" to {$ICON_APPS_X, $ICON_APPS_Y}
    update without registering applications
    delay 1
    close
    open
    delay 1
  end tell
end tell
EOF
}

ok=0
for attempt in 1 2 3 4 5; do
  if configure_finder; then
    ok=1
    break
  fi
  echo "warning: Finder DMG layout attempt $attempt failed; retrying…" >&2
  sleep 2
done
if [[ "$ok" -ne 1 ]]; then
  echo "error: could not apply DMG Finder layout via AppleScript" >&2
  exit 1
fi

# Flush .DS_Store before detach.
sync
sleep 2
detach_volume "$VOLUME"
VOLUME=""
wait_image_free "$RW_DMG"
sync
sleep 1

# Compressed final image (retries absorb DiskImages EAGAIN under load).
convert_udzo "$RW_DMG" "$DMG_PATH"
rm -f "$RW_DMG"

echo "Created $DMG_PATH"
