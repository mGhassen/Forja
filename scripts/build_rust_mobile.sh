#!/usr/bin/env bash
# Cross-compile ffi for iOS/Android.
#
# Default: full features (torrent-engine + local-proxy + parsers).
# Parser-only (legacy): RUST_MOBILE_PARSER_ONLY=1
#
# Android: needs NDK (Android Studio, ANDROID_NDK_HOME, or sdk.dir in local.properties)
# iOS: macOS + Xcode toolchain
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"

PROFILE="${RUST_PROFILE:-release}"
MOBILE_FLAGS=()
if [[ "${RUST_MOBILE_PARSER_ONLY:-}" == "1" ]]; then
  MOBILE_FLAGS=(--no-default-features)
  echo "Building mobile FFI parsers only (no torrent/proxy)."
fi

build_ios() {
  echo "==> iOS arm64"
  rustup target add aarch64-apple-ios >/dev/null 2>&1 || true
  cargo build -p ffi --target aarch64-apple-ios "--$PROFILE" "${MOBILE_FLAGS[@]}"
  local out="$ROOT/crates/target/aarch64-apple-ios/$PROFILE/libffi.dylib"
  local dest="$ROOT/apps/forja/ios/Runner/Frameworks"
  mkdir -p "$dest"
  cp -f "$out" "$dest/libffi.dylib"
  echo "Copied -> $dest/libffi.dylib"
}

ndk_host_prebuilt() {
  local ndk="$1"
  local base="$ndk/toolchains/llvm/prebuilt"
  local host
  host="$(resolve_ndk_host)"
  if [[ -d "$base/$host" ]]; then
    echo "$base/$host"
    return
  fi
  if [[ "$(uname -s)" == "Darwin" && -d "$base/darwin-x86_64" ]]; then
    echo "$base/darwin-x86_64"
    return
  fi
  echo ""
}

resolve_ndk_host() {
  case "$(uname -s)/$(uname -m)" in
    Darwin/arm64) echo "darwin-arm64" ;;
    Darwin/x86_64) echo "darwin-x86_64" ;;
    Linux/x86_64) echo "linux-x86_64" ;;
    Linux/aarch64) echo "linux-aarch64" ;;
    *) echo "linux-x86_64" ;;
  esac
}

read_local_sdk_dir() {
  local props="$ROOT/apps/forja/android/local.properties"
  [[ -f "$props" ]] || return 1
  local line
  line="$(grep -E '^sdk\.dir=' "$props" | head -1 || true)"
  [[ -n "$line" ]] || return 1
  local dir="${line#sdk.dir=}"
  dir="${dir//\\:/:}"
  dir="${dir//\\//}"
  echo "$dir"
}

latest_ndk_in() {
  local parent="$1"
  [[ -d "$parent" ]] || return 1
  local latest
  latest="$(ls -1d "$parent"/* 2>/dev/null | sort -V | tail -1 || true)"
  [[ -n "$latest" && -d "$latest" ]] || return 1
  echo "$latest"
}

resolve_ndk() {
  if [[ -n "${ANDROID_NDK_HOME:-}" && -d "$ANDROID_NDK_HOME" ]]; then
    echo "$ANDROID_NDK_HOME"
    return
  fi
  if [[ -n "${ANDROID_NDK_ROOT:-}" && -d "$ANDROID_NDK_ROOT" ]]; then
    echo "$ANDROID_NDK_ROOT"
    return
  fi

  local sdk
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}"; do
    if [[ -n "$sdk" ]]; then
      local ndk
      ndk="$(latest_ndk_in "$sdk/ndk")" && echo "$ndk" && return
    fi
  done

  if sdk="$(read_local_sdk_dir)"; then
    local ndk
    ndk="$(latest_ndk_in "$sdk/ndk")" && echo "$ndk" && return
  fi

  if [[ -d "$HOME/Library/Android/sdk/ndk" ]]; then
    latest_ndk_in "$HOME/Library/Android/sdk/ndk" && return
  fi

  if [[ -d "$HOME/Android/Sdk/ndk" ]]; then
    latest_ndk_in "$HOME/Android/Sdk/ndk" && return
  fi

  echo ""
}

build_android() {
  local ndk
  ndk="$(resolve_ndk)"
  if [[ -z "$ndk" ]]; then
    echo "error: Android NDK not found." >&2
    echo "  Install Android Studio NDK, or set ANDROID_NDK_HOME, or sdk.dir in apps/forja/android/local.properties" >&2
    exit 1
  fi

  local prebuilt
  prebuilt="$(ndk_host_prebuilt "$ndk")"
  if [[ -z "$prebuilt" ]]; then
    echo "error: NDK LLVM prebuilt not found under $ndk/toolchains/llvm/prebuilt" >&2
    exit 1
  fi

  export ANDROID_NDK_HOME="$ndk"
  echo "==> Android arm64 (NDK: $ndk)"
  rustup target add aarch64-linux-android >/dev/null 2>&1 || true

  export CC="$prebuilt/bin/aarch64-linux-android21-clang"
  export CXX="$prebuilt/bin/aarch64-linux-android21-clang++"
  export AR="$prebuilt/bin/llvm-ar"
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CC"

  cargo build -p ffi --target aarch64-linux-android "--$PROFILE" "${MOBILE_FLAGS[@]}"
  local out="$ROOT/crates/target/aarch64-linux-android/$PROFILE/libffi.so"
  local dest="$ROOT/apps/forja/android/app/src/main/jniLibs/arm64-v8a"
  mkdir -p "$dest"
  cp -f "$out" "$dest/libffi.so"
  echo "Copied -> $dest/libffi.so"
}

case "${1:-all}" in
  ios) build_ios ;;
  android) build_android ;;
  all)
    if [[ "$(uname -s)" == "Darwin" ]]; then
      build_ios
    fi
    build_android
    ;;
  *)
    echo "Usage: $0 [ios|android|all]" >&2
    exit 1
    ;;
esac

if [[ "${#MOBILE_FLAGS[@]}" -gt 0 ]]; then
  echo "Mobile Rust engine built (full features — librqbit torrent + proxy)."
else
  echo "Mobile Rust engine built (full features: parsers + librqbit + proxy)."
fi
