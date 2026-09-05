#!/usr/bin/env bash
# Probe whether ffi can cross-compile with torrent-engine on mobile.
# Usage: try_build_mobile_torrent.sh [ios|android|all]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"
TARGET="${1:-ios}"
FEATURES="torrent-engine,local-proxy"
PROFILE="${RUST_PROFILE:-release}"

resolve_ndk() {
  if [[ -n "${ANDROID_NDK_HOME:-}" && -d "$ANDROID_NDK_HOME" ]]; then
    echo "$ANDROID_NDK_HOME"
    return
  fi
  local props="$ROOT/apps/forja/android/local.properties"
  if [[ -f "$props" ]]; then
    local sdk line dir ndk
    line="$(grep -E '^sdk\.dir=' "$props" | head -1 || true)"
    if [[ -n "$line" ]]; then
      dir="${line#sdk.dir=}"
      dir="${dir//\\:/:}"
      dir="${dir//\\//}"
      ndk="$(ls -1d "$dir/ndk"/* 2>/dev/null | sort -V | tail -1 || true)"
      [[ -n "$ndk" && -d "$ndk" ]] && echo "$ndk" && return
    fi
  fi
  if [[ -d "$HOME/Library/Android/sdk/ndk" ]]; then
    ls -1d "$HOME/Library/Android/sdk/ndk"/* 2>/dev/null | sort -V | tail -1
    return
  fi
  echo ""
}

build_ios() {
  echo "==> iOS arm64 + $FEATURES"
  rustup target add aarch64-apple-ios >/dev/null 2>&1 || true
  cargo build -p ffi --target aarch64-apple-ios "--$PROFILE" --features "$FEATURES"
}

build_android() {
  echo "==> Android arm64 + $FEATURES"
  local ndk
  ndk="$(resolve_ndk)"
  if [[ -z "$ndk" ]]; then
    echo "error: Android NDK not found" >&2
    return 1
  fi
  export ANDROID_NDK_HOME="$ndk"
  local prebuilt sysroot ndk_toolchain wrap
  prebuilt="$(ls -d "$ndk/toolchains/llvm/prebuilt/"* 2>/dev/null | head -1)"
  sysroot="$prebuilt/sysroot"
  ndk_toolchain="$ndk/build/cmake/android.toolchain.cmake"
  wrap="$ROOT/crates/target/forja-ndk-cmake/arm64-v8a/android.toolchain.cmake"
  mkdir -p "$(dirname "$wrap")"
  cat >"$wrap" <<EOF
set(ANDROID_ABI arm64-v8a CACHE STRING "" FORCE)
set(ANDROID_PLATFORM android-21 CACHE STRING "" FORCE)
set(ANDROID_STL c++_shared CACHE STRING "" FORCE)
include("${ndk_toolchain}")
EOF
  # Same as build_rust_mobile.sh: wrappers for cc-rs + CMAKE_TOOLCHAIN_FILE so
  # btls-sys does not inject CC into cmake (always_configure compiler flip).
  unset CC CXX AR CFLAGS CXXFLAGS SDKROOT MACOSX_DEPLOYMENT_TARGET CMAKE_TOOLCHAIN_FILE || true
  export CC_aarch64_linux_android="$prebuilt/bin/aarch64-linux-android21-clang"
  export CXX_aarch64_linux_android="$prebuilt/bin/aarch64-linux-android21-clang++"
  export AR_aarch64_linux_android="$prebuilt/bin/llvm-ar"
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CC_aarch64_linux_android"
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="$AR_aarch64_linux_android"
  export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android="--sysroot=$sysroot"
  export CMAKE_TOOLCHAIN_FILE_aarch64_linux_android="$wrap"
  rustup target add aarch64-linux-android >/dev/null 2>&1 || true
  cargo build -p ffi --target aarch64-linux-android "--$PROFILE" --features "$FEATURES"
}

failed=0
case "$TARGET" in
  ios) build_ios || failed=1 ;;
  android) build_android || failed=1 ;;
  all)
    build_ios || failed=1
    build_android || failed=1
    ;;
  *)
    echo "Usage: $0 [ios|android|all]" >&2
    exit 2
    ;;
esac

if [[ "$failed" -ne 0 ]]; then
  echo "Mobile torrent FFI build failed ($TARGET)." >&2
  exit 1
fi

echo "Mobile torrent FFI build succeeded ($TARGET)."
