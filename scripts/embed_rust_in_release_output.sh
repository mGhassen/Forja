#!/usr/bin/env bash
set -euo pipefail

# Copy Rust FFI into flutter release output (run after flutter build).
# Usage: embed_rust_in_release_output.sh [macos|windows|linux]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/forja"
PROFILE="${RUST_PROFILE:-release}"
OUT="$ROOT/crates/target/$PROFILE"

platform="${1:-$(uname -s)}"
case "$platform" in
  macos|Darwin) platform=macos ;;
  windows|MINGW*|MSYS*|CYGWIN*) platform=windows ;;
  linux|Linux) platform=linux ;;
esac

copy_lib() {
  local src="$1" dest="$2"
  if [[ ! -f "$src" ]]; then
    echo "error: missing $src — run build_rust_release.sh first" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dest")"
  cp -f "$src" "$dest"
  echo "Embedded $(basename "$src") -> $dest"
}

case "$platform" in
  macos)
  # Xcode copy_rust_dylib.sh handles .app; verify only.
    ;;
  windows)
    copy_lib "$OUT/ffi.dll" "$APP/build/windows/x64/runner/Release/ffi.dll"
    ;;
  linux)
    copy_lib "$OUT/libffi.so" "$APP/build/linux/x64/release/bundle/lib/libffi.so"
    ;;
  *)
    echo "unsupported platform: $platform" >&2
    exit 1
    ;;
esac
