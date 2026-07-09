#!/usr/bin/env bash
set -euo pipefail

# Build AppImage from flutter linux release bundle.
# Usage: package_linux_appimage.sh <version>
# Output: dist/Forja-<version>-linux-x86_64.AppImage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: package_linux_appimage.sh <version>}"
APP="$ROOT/apps/forja"
BUNDLE="$APP/build/linux/x64/release/bundle"
DIST="$ROOT/dist"
APPDIR="$DIST/Forja.AppDir"
OUTPUT="$DIST/Forja-${VERSION}-linux-x86_64.AppImage"
ICON_SRC="$APP/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
DESKTOP_SRC="$ROOT/installer/linux/Forja.desktop"
TOOLS_DIR="$DIST/linuxdeploy-tools"

LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
GTK_PLUGIN_REF=3b67a1d1c1b0c8268f57f2bce40fe2d33d409cea
LINUXDEPLOY_GTK="$TOOLS_DIR/linuxdeploy-plugin-gtk.sh"

if [[ ! -d "$BUNDLE" ]]; then
  echo "error: missing $BUNDLE — run flutter build linux --release first" >&2
  exit 1
fi

if [[ ! -f "$BUNDLE/lib/libffi.so" ]]; then
  echo "error: libffi.so missing from bundle — run embed_rust_in_release_output.sh linux" >&2
  exit 1
fi

mkdir -p "$DIST" "$TOOLS_DIR" "$APPDIR/usr/bin"
cd "$TOOLS_DIR"

if [[ ! -x "$LINUXDEPLOY" ]]; then
  curl -fsSL -o "$LINUXDEPLOY" \
    "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
  chmod +x "$LINUXDEPLOY"
fi

if [[ ! -x "$LINUXDEPLOY_GTK" ]]; then
  curl -fsSL -o "$LINUXDEPLOY_GTK" \
    "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/${GTK_PLUGIN_REF}/linuxdeploy-plugin-gtk.sh"
  chmod +x "$LINUXDEPLOY_GTK"
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"

cp "$BUNDLE/forja" "$APPDIR/usr/bin/"
cp -a "$BUNDLE/lib" "$APPDIR/usr/bin/"
cp -a "$BUNDLE/data" "$APPDIR/usr/bin/"
cp "$DESKTOP_SRC" "$APPDIR/forja.desktop"
cp "$ICON_SRC" "$APPDIR/forja.png"

cat >"$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/usr/bin/forja" "$@"
EOF
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/forja"

export ARCH=x86_64
export VERSION="$VERSION"
export APPIMAGE_EXTRACT_AND_RUN=1
export PATH="$TOOLS_DIR:$PATH"

"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --desktop-file="$APPDIR/forja.desktop" \
  --icon-file="$APPDIR/forja.png" \
  --plugin gtk \
  --output appimage

BUILT="$(find "$TOOLS_DIR" -maxdepth 1 -name '*.AppImage' -newer "$LINUXDEPLOY" 2>/dev/null | head -1 || true)"
if [[ -z "$BUILT" ]]; then
  BUILT="$(ls -1t "$TOOLS_DIR"/*.AppImage 2>/dev/null | head -1 || true)"
fi

if [[ -z "$BUILT" || ! -f "$BUILT" ]]; then
  echo "error: linuxdeploy did not produce an AppImage" >&2
  exit 1
fi

mv -f "$BUILT" "$OUTPUT"
chmod +x "$OUTPUT"
echo "Created $OUTPUT"
