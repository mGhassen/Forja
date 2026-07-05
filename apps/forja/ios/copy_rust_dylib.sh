#!/bin/sh
# Embeds libforja_ffi.dylib into the iOS app bundle Frameworks folder.
set -e
DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "$DEST"
for SRC in \
  "${SRCROOT}/Runner/Frameworks/libforja_ffi.dylib" \
  "${SRCROOT}/../../crates/target/aarch64-apple-ios/release/libforja_ffi.dylib"
do
  if [ -f "$SRC" ]; then
    cp -f "$SRC" "$DEST/libforja_ffi.dylib"
    echo "Copied Rust engine: $SRC -> $DEST"
    exit 0
  fi
done
echo "warning: libforja_ffi.dylib not found — run ./scripts/build_rust_mobile.sh ios"
exit 0
