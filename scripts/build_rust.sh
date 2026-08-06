#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"

PROFILE="${RUST_PROFILE:-release}"
cargo build -p ffi "--$PROFILE"
cargo test --workspace

OUT="$ROOT/crates/target/$PROFILE"
APP="$ROOT/apps/forja"

copy_lib() {
  local src="$1" dest_dir="$2"
  mkdir -p "$dest_dir"
  cp -f "$src" "$dest_dir/"
  if [[ "$(uname -s)" == Darwin && "$(basename "$src")" == libffi.dylib ]]; then
    install_name_tool -id "@rpath/libffi.dylib" "$dest_dir/libffi.dylib"
    codesign --force --sign - "$dest_dir/libffi.dylib" 2>/dev/null || true
  fi
  echo "Copied $(basename "$src") -> $dest_dir"
}

case "$(uname -s)" in
  Darwin)
  if [[ -f "$OUT/libffi.dylib" ]]; then
    copy_lib "$OUT/libffi.dylib" "$APP/macos/Runner/Frameworks"
    # flutter run loads the dylib from the built .app, not Runner/Frameworks.
    # Without this copy, protocol-relative HLS rewrites stay on a stale binary.
    for app_fw in \
      "$APP/build/macos/Build/Products/Debug/Forja.app/Contents/Frameworks" \
      "$APP/build/macos/Build/Products/Release/Forja.app/Contents/Frameworks" \
      "$APP/build/macos/Build/Products/Profile/Forja.app/Contents/Frameworks"
    do
      if [[ -d "$app_fw" ]]; then
        copy_lib "$OUT/libffi.dylib" "$app_fw"
      fi
    done
  fi
  ;;
  Linux)
  if [[ -f "$OUT/libffi.so" ]]; then
    copy_lib "$OUT/libffi.so" "$APP/linux/lib"
  fi
  ;;
  MINGW*|MSYS*|CYGWIN*)
  if [[ -f "$OUT/ffi.dll" ]]; then
    copy_lib "$OUT/ffi.dll" "$APP/windows/runner"
  fi
  ;;
esac

echo "Rust engine built: crates/target/$PROFILE/libffi.*"
