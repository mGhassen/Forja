#!/usr/bin/env bash
# Verify mobile Rust FFI artifacts exist (run after build_rust_mobile.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_SO="$ROOT/apps/forja/android/app/src/main/jniLibs/arm64-v8a/libforja_ffi.so"
IOS_DYLIB="$ROOT/apps/forja/ios/Runner/Frameworks/libforja_ffi.dylib"

missing=0
for path in "$ANDROID_SO" "$IOS_DYLIB"; do
  if [[ -f "$path" ]]; then
    echo "OK  $path"
  else
    echo "MISSING  $path"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Run: ./scripts/build_rust_mobile.sh all" >&2
  exit 1
fi

echo "Mobile Rust release artifacts present."
