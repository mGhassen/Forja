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

# media_kit_libs_linux registers the plugin but does not bundle libmpv (unlike Windows).
# Copy the build-host libmpv into bundle/lib so AppImage LD_LIBRARY_PATH can load it.
embed_linux_libmpv() {
  local lib_dir="$1"
  mkdir -p "$lib_dir"

  local mpv_so=""
  if command -v pkg-config >/dev/null 2>&1; then
    local libdir
    libdir="$(pkg-config --variable=libdir mpv 2>/dev/null || true)"
    if [[ -n "$libdir" ]]; then
      if [[ -e "$libdir/libmpv.so" ]]; then
        mpv_so="$libdir/libmpv.so"
      else
        mpv_so="$(find "$libdir" -maxdepth 1 -name 'libmpv.so.*' -type f,l 2>/dev/null | sort -V | tail -1 || true)"
      fi
    fi
  fi

  if [[ -z "$mpv_so" || ! -e "$mpv_so" ]]; then
    mpv_so="$(ldconfig -p 2>/dev/null | awk '/libmpv\.so(\.[0-9]+)?$/ {print $NF; exit}')"
  fi

  if [[ -z "$mpv_so" || ! -e "$mpv_so" ]]; then
    for candidate in \
      /usr/lib/x86_64-linux-gnu/libmpv.so.2 \
      /usr/lib/libmpv.so.2; do
      if [[ -e "$candidate" ]]; then
        mpv_so="$candidate"
        break
      fi
    done
  fi

  if [[ -z "$mpv_so" || ! -e "$mpv_so" ]]; then
    echo "error: libmpv not found on build host — install libmpv-dev (or libmpv2)" >&2
    exit 1
  fi

  local resolved versioned_name
  resolved="$(readlink -f "$mpv_so")"
  versioned_name="$(basename "$resolved")"
  cp -f "$resolved" "$lib_dir/$versioned_name"
  ln -sfn "$versioned_name" "$lib_dir/libmpv.so"
  if [[ "$versioned_name" != libmpv.so.2 ]]; then
    ln -sfn "$versioned_name" "$lib_dir/libmpv.so.2"
  fi
  echo "Embedded libmpv ($versioned_name) -> $lib_dir"
}

case "$platform" in
  macos)
  # Xcode copy_rust_dylib.sh handles .app; verify only.
    ;;
  windows)
    copy_lib "$OUT/ffi.dll" "$APP/build/windows/x64/runner/Release/ffi.dll"
    ;;
  linux)
    BUNDLE_LIB="$APP/build/linux/x64/release/bundle/lib"
    copy_lib "$OUT/libffi.so" "$BUNDLE_LIB/libffi.so"
    embed_linux_libmpv "$BUNDLE_LIB"
    ;;
  *)
    echo "unsupported platform: $platform" >&2
    exit 1
    ;;
esac
