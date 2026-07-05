#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"

PROFILE="${FORJA_RUST_PROFILE:-release}"
cargo build -p ffi "--$PROFILE"
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
  if [[ -f "$OUT/libffi.dylib" ]]; then
    copy_lib "$OUT/libffi.dylib" "$APP/macos/Runner/Frameworks"
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
