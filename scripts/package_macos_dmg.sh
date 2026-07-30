#!/usr/bin/env bash
set -euo pipefail

# Create a drag-to-Applications DMG (large icons, matrix-style light background).
# Usage: package_macos_dmg.sh <version> [arch]
#   arch: arm64 | x86_64 (default: host machine from uname -m)
# Output: dist/Forja-<version>-macos-<arch>.dmg
#
# Finder layout lives in .DS_Store. AppleScript alone often "succeeds" without
# writing it (especially when another /Volumes/Forja* is already mounted).
# This script ejects collisions, polls for .DS_Store, and remount-verifies the
# final UDZO — packaging fails hard if layout did not stick.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: package_macos_dmg.sh <version> [arch]}"
APP="$ROOT/apps/forja"
RELEASE_DIR="$APP/build/macos/Build/Products/Release"
BACKGROUND="$ROOT/scripts/dmg/background.png"
DS_STORE_TEMPLATE="$ROOT/scripts/dmg/DS_Store"
DIST="$ROOT/dist"
STAGING="$DIST/dmg-staging"
RW_DMG="$DIST/dmg-rw-$$.dmg"
MOUNT_ROOT="/Volumes"
# Distinct from bare "Forja" so a user-opened old DMG cannot steal AppleScript.
VOLNAME="Install Forja"
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

# Eject leftover installer volumes for our VOLNAME. Legacy "Forja" eject is
# best-effort (user may have an old ship open — we no longer share that name).
eject_installer_volumes() {
  local vol name
  shopt -s nullglob
  for vol in "$MOUNT_ROOT/Forja" "$MOUNT_ROOT/Forja "*; do
    [[ -e "$vol" ]] || continue
    name="$(basename "$vol")"
    echo "warning: ejecting legacy volume $vol (best-effort)" >&2
    osascript -e "tell application \"Finder\" to eject disk \"$name\"" 2>/dev/null || true
    detach_volume "$vol" || true
  done
  for vol in "$MOUNT_ROOT/$VOLNAME" "$MOUNT_ROOT/$VOLNAME "*; do
    [[ -e "$vol" ]] || continue
    name="$(basename "$vol")"
    echo "ejecting colliding volume: $vol" >&2
    osascript -e "tell application \"Finder\" to eject disk \"$name\"" 2>/dev/null || true
    detach_volume "$vol" || true
  done
  shopt -u nullglob
  sleep 1
  if [[ -e "$MOUNT_ROOT/$VOLNAME" ]]; then
    echo "error: could not eject $MOUNT_ROOT/$VOLNAME — eject it in Finder and retry" >&2
    exit 1
  fi
}

wait_image_free() {
  local image="$1"
  local i
  for i in 1 2 3 4 5 6 7 8; do
    if ! hdiutil info 2>/dev/null | grep -F "$image" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
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

wait_for_ds_store() {
  local vol="$1"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if [[ -f "$vol/.DS_Store" && "$(stat -f%z "$vol/.DS_Store" 2>/dev/null || echo 0)" -gt 100 ]]; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

configure_finder() {
  # Longer open/close cycle so Finder actually flushes .DS_Store to the volume.
  osascript <<EOF
tell application "Finder"
  activate
  tell disk "$VOLNAME"
    open
    delay 1
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
    delay 2
    close
    delay 1
    open
    delay 2
    close
  end tell
end tell
EOF
}

seed_ds_store_from_template() {
  local vol="$1"
  if [[ -f "$DS_STORE_TEMPLATE" ]]; then
    cp "$DS_STORE_TEMPLATE" "$vol/.DS_Store"
    # Hide from icon view (name still reserved for Finder).
    chflags hidden "$vol/.DS_Store" 2>/dev/null || true
    echo "seeded .DS_Store from $DS_STORE_TEMPLATE" >&2
    return 0
  fi
  return 1
}

save_ds_store_template() {
  local vol="$1"
  if [[ -f "$vol/.DS_Store" ]]; then
    mkdir -p "$(dirname "$DS_STORE_TEMPLATE")"
    cp "$vol/.DS_Store" "$DS_STORE_TEMPLATE"
    echo "saved layout template → $DS_STORE_TEMPLATE" >&2
  fi
}

verify_final_dmg() {
  local dmg="$1"
  local attach_out volume
  eject_installer_volumes
  attach_out="$(hdiutil attach -readonly -nobrowse -noverify -noautoopen "$dmg")"
  volume="$MOUNT_ROOT/$VOLNAME"
  if [[ ! -d "$volume" ]]; then
    volume="$(echo "$attach_out" | awk '/\/Volumes\// {print $NF; exit}')"
  fi
  if [[ ! -d "$volume" ]]; then
    echo "error: could not remount final DMG for layout verify" >&2
    echo "$attach_out" >&2
    return 1
  fi
  if [[ ! -f "$volume/.DS_Store" ]]; then
    echo "error: final DMG missing .DS_Store — Finder layout did not stick" >&2
    detach_volume "$volume" || true
    return 1
  fi
  if [[ ! -f "$volume/.background/background.png" ]]; then
    echo "error: final DMG missing background.png" >&2
    detach_volume "$volume" || true
    return 1
  fi
  echo "verified final DMG layout (.DS_Store + background present)" >&2
  detach_volume "$volume" || true
  wait_image_free "$dmg"
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

eject_installer_volumes

rm -rf "$STAGING" "$DMG_PATH" "$RW_DMG"
mkdir -p "$STAGING/.background" "$DIST"

cp -R "$APP_BUNDLE" "$STAGING/$APP_NAME"
ln -s /Applications "$STAGING/Applications"
cp "$BACKGROUND" "$STAGING/.background/background.png"
# Prefer a known-good layout blob when present (deterministic; no Finder race).
if [[ -f "$DS_STORE_TEMPLATE" ]]; then
  cp "$DS_STORE_TEMPLATE" "$STAGING/.DS_Store"
fi

hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG"

ATTACH_OUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
VOLUME="$MOUNT_ROOT/$VOLNAME"
if [[ ! -d "$VOLUME" ]]; then
  VOLUME="$(echo "$ATTACH_OUT" | awk '/\/Volumes\// {print $NF; exit}')"
fi
if [[ ! -d "$VOLUME" ]]; then
  echo "error: failed to mount $RW_DMG" >&2
  echo "$ATTACH_OUT" >&2
  exit 1
fi
if [[ "$VOLUME" != "$MOUNT_ROOT/$VOLNAME" ]]; then
  echo "error: mounted as $VOLUME (expected $MOUNT_ROOT/$VOLNAME) — eject other Forja volumes" >&2
  exit 1
fi

# Always run AppleScript so window bounds / icon positions match this script's
# constants even when a template was seeded (template may be from an older layout).
ok=0
for attempt in 1 2 3 4 5 6 7 8; do
  if configure_finder && wait_for_ds_store "$VOLUME"; then
    ok=1
    break
  fi
  echo "warning: Finder DMG layout attempt $attempt did not produce .DS_Store; retrying…" >&2
  seed_ds_store_from_template "$VOLUME" || true
  sleep 2
done

# Last resort: template alone (positions may be slightly stale vs constants).
if [[ "$ok" -ne 1 ]]; then
  if seed_ds_store_from_template "$VOLUME" && wait_for_ds_store "$VOLUME"; then
    echo "warning: using seeded .DS_Store template only (AppleScript did not flush)" >&2
    ok=1
  fi
fi

if [[ "$ok" -ne 1 || ! -f "$VOLUME/.DS_Store" ]]; then
  echo "error: could not write .DS_Store — DMG would open as plain Finder defaults" >&2
  exit 1
fi

save_ds_store_template "$VOLUME"

# Flush before detach.
sync
sleep 2
# Close any Finder windows still holding the volume.
osascript -e 'tell application "Finder" to close every window whose name is "'"$VOLNAME"'"' 2>/dev/null || true
sleep 1
detach_volume "$VOLUME"
VOLUME=""
wait_image_free "$RW_DMG"
sync
sleep 1

convert_udzo "$RW_DMG" "$DMG_PATH"
rm -f "$RW_DMG"

verify_final_dmg "$DMG_PATH"

echo "Created $DMG_PATH"
