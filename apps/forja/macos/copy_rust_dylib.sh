#!/bin/sh
# Embeds libffi.dylib into the .app bundle Frameworks folder.
set -e
DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "$DEST"
for SRC in \
  "${SRCROOT}/../../crates/target/release/libffi.dylib" \
  "${SRCROOT}/Runner/Frameworks/libffi.dylib"
do
  if [ -f "$SRC" ]; then
    cp -f "$SRC" "$DEST/libffi.dylib"
    echo "Copied Rust engine: $SRC -> $DEST"
    exit 0
  fi
done
echo "warning: libffi.dylib not found — run ./scripts/build_rust.sh (Dart fallbacks active)"
exit 0
