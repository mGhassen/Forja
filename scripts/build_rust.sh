#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"

PROFILE="${FORJA_RUST_PROFILE:-release}"
cargo build -p forja-ffi "--$PROFILE"
cargo test --workspace

OUT="$ROOT/crates/target/$PROFILE"
APP="$ROOT/apps/forja"

copy_lib() {
  local src="$1" dest_dir="$2"
  mkdir -p "$dest_dir"
  cp -f "$src" "$dest_dir/"
  echo "Copied $(basename "$src") -> $dest_dir"
}

case "$(uname -s)" in
  Darwin)
  if [[ -f "$OUT/libforja_ffi.dylib" ]]; then
    copy_lib "$OUT/libforja_ffi.dylib" "$APP/macos/Runner/Frameworks"
  fi
  ;;
  Linux)
  if [[ -f "$OUT/libforja_ffi.so" ]]; then
    copy_lib "$OUT/libforja_ffi.so" "$APP/linux/lib"
  fi
  ;;
  MINGW*|MSYS*|CYGWIN*)
  if [[ -f "$OUT/forja_ffi.dll" ]]; then
    copy_lib "$OUT/forja_ffi.dll" "$APP/windows/runner"
  fi
  ;;
esac

echo "Rust engine built: crates/target/$PROFILE/libforja_ffi.*"
