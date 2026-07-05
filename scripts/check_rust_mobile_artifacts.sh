#!/usr/bin/env bash
# Verify mobile Rust FFI artifacts exist (run after build_rust_mobile.sh).
# Usage: check_rust_mobile_artifacts.sh [android|ios|all]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-all}"
ANDROID_SO="$ROOT/apps/forja/android/app/src/main/jniLibs/arm64-v8a/libffi.so"
IOS_DYLIB="$ROOT/apps/forja/ios/Runner/Frameworks/libffi.dylib"

check_android() {
  if [[ -f "$ANDROID_SO" ]]; then
    echo "OK  $ANDROID_SO"
  else
    echo "MISSING  $ANDROID_SO"
    return 1
  fi
}

check_ios() {
  if [[ -f "$IOS_DYLIB" ]]; then
    echo "OK  $IOS_DYLIB"
  else
    echo "MISSING  $IOS_DYLIB"
    return 1
  fi
}

missing=0
case "$TARGET" in
  android) check_android || missing=1 ;;
  ios) check_ios || missing=1 ;;
  all)
    check_android || missing=1
    check_ios || missing=1
    ;;
  *)
    echo "Usage: $0 [android|ios|all]" >&2
    exit 2
    ;;
esac

if [[ "$missing" -ne 0 ]]; then
  echo "Run: ./scripts/build_rust_mobile.sh $TARGET" >&2
  exit 1
fi

echo "Mobile Rust artifact(s) present ($TARGET)."
