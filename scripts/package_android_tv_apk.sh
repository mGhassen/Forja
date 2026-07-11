#!/usr/bin/env bash
set -euo pipefail

# Rename split-per-abi release APKs to Forja release asset names.
# Usage: package_android_tv_apk.sh <version>
# Output:
#   dist/Forja-<version>-android-tv-arm64.apk
#   dist/Forja-<version>-android-tv-armeabi-v7a.apk

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: package_android_tv_apk.sh <version>}"
APK_DIR="$ROOT/apps/forja/build/app/outputs/flutter-apk"
DIST="$ROOT/dist"

SRC_ARM64="$APK_DIR/app-arm64-v8a-release.apk"
SRC_V7A="$APK_DIR/app-armeabi-v7a-release.apk"
OUT_ARM64="$DIST/Forja-${VERSION}-android-tv-arm64.apk"
OUT_V7A="$DIST/Forja-${VERSION}-android-tv-armeabi-v7a.apk"

verify_libffi() {
  local apk="$1"
  local lib_path="$2"
  if ! unzip -l "$apk" | grep -Fq "$lib_path"; then
    echo "error: $apk missing $lib_path" >&2
    exit 1
  fi
}

if [[ ! -f "$SRC_ARM64" ]]; then
  echo "error: missing $SRC_ARM64 — run flutter build apk --release --split-per-abi first" >&2
  exit 1
fi

if [[ ! -f "$SRC_V7A" ]]; then
  echo "error: missing $SRC_V7A — run flutter build apk --release --split-per-abi first" >&2
  exit 1
fi

mkdir -p "$DIST"
cp -f "$SRC_ARM64" "$OUT_ARM64"
cp -f "$SRC_V7A" "$OUT_V7A"

verify_libffi "$OUT_ARM64" "lib/arm64-v8a/libffi.so"
verify_libffi "$OUT_V7A" "lib/armeabi-v7a/libffi.so"

echo "Created $OUT_ARM64"
echo "Created $OUT_V7A"
