#!/bin/sh
# Embeds libffi.dylib into the iOS app bundle Frameworks folder.
set -e
DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "$DEST"
for SRC in \
  "${SRCROOT}/Runner/Frameworks/libffi.dylib" \
  "${SRCROOT}/../../crates/target/aarch64-apple-ios/release/libffi.dylib"
do
  if [ -f "$SRC" ]; then
    cp -f "$SRC" "$DEST/libffi.dylib"
    echo "Copied Rust engine: $SRC -> $DEST"
    exit 0
  fi
done
echo "warning: libffi.dylib not found — run ./scripts/build_rust_mobile.sh ios"
exit 0
