#!/usr/bin/env bash
# Probe whether forja-ffi can cross-compile with torrent-engine on mobile.
# Expected to fail on iOS today (librqbit-dualstack-sockets bind_device).
# Usage: try_build_mobile_torrent.sh [ios|android|all]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"
TARGET="${1:-ios}"
FEATURES="torrent-engine,local-proxy"
PROFILE="${FORJA_RUST_PROFILE:-release}"

build_ios() {
  echo "==> iOS arm64 + $FEATURES"
  rustup target add aarch64-apple-ios >/dev/null 2>&1 || true
  cargo build -p forja-ffi --target aarch64-apple-ios "--$PROFILE" --features "$FEATURES"
}

build_android() {
  echo "==> Android arm64 + $FEATURES"
  if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    echo "error: set ANDROID_NDK_HOME or run from CI with setup-ndk" >&2
    return 1
  fi
  local prebuilt
  prebuilt="$(ls -d "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/* 2>/dev/null | head -1)"
  export CC="$prebuilt/bin/aarch64-linux-android21-clang"
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CC"
  rustup target add aarch64-linux-android >/dev/null 2>&1 || true
  cargo build -p forja-ffi --target aarch64-linux-android "--$PROFILE" --features "$FEATURES"
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
  cat >&2 <<'EOF'

Mobile torrent FFI build failed.
Known iOS issue: librqbit-dualstack-sockets 0.7 — Socket::bind_device unsupported on iOS.
Magnet playback on mobile stays libtorrent_flutter until upstream fixes or we patch deps.
EOF
  exit 1
fi

echo "Mobile torrent FFI build succeeded ($TARGET)."
