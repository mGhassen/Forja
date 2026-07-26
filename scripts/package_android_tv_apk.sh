#!/usr/bin/env bash
set -euo pipefail

# Rename split-per-abi release APKs to Forja release asset names.
# Usage: package_android_tv_apk.sh <version> [arm64|armeabi-v7a]...
#   No ABI args → both (local release default).
# Output (per selected ABI):
#   dist/Forja-<version>-android-tv-arm64.apk
#   dist/Forja-<version>-android-tv-armeabi-v7a.apk

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: package_android_tv_apk.sh <version> [arm64|armeabi-v7a]...}"
shift || true
APK_DIR="$ROOT/apps/forja/build/app/outputs/flutter-apk"
DIST="$ROOT/dist"

if [[ $# -eq 0 ]]; then
  set -- arm64 armeabi-v7a
fi

verify_libffi() {
  local apk="$1"
  local lib_path="$2"
  local listing
  # Avoid `unzip | grep -q` under pipefail — grep -q exits early → SIGPIPE → false failure.
  listing="$(unzip -l "$apk")"
  if ! grep -Fq "$lib_path" <<<"$listing"; then
    echo "error: $apk missing $lib_path" >&2
    exit 1
  fi
}

mkdir -p "$DIST"
created=0

for abi in "$@"; do
  case "$abi" in
    arm64|arm64-v8a)
      src="$APK_DIR/app-arm64-v8a-release.apk"
      out="$DIST/Forja-${VERSION}-android-tv-arm64.apk"
      lib="lib/arm64-v8a/libffi.so"
      ;;
    armeabi-v7a|v7a|arm)
      src="$APK_DIR/app-armeabi-v7a-release.apk"
      out="$DIST/Forja-${VERSION}-android-tv-armeabi-v7a.apk"
      lib="lib/armeabi-v7a/libffi.so"
      ;;
    *)
      echo "error: unknown ABI '$abi' (want arm64 or armeabi-v7a)" >&2
      exit 1
      ;;
  esac

  if [[ ! -f "$src" ]]; then
    echo "error: missing $src — run flutter build apk --release --split-per-abi first" >&2
    exit 1
  fi

  cp -f "$src" "$out"
  verify_libffi "$out" "$lib"
  echo "Created $out"
  created=$((created + 1))
done

if [[ "$created" -eq 0 ]]; then
  echo "error: no APKs packaged" >&2
  exit 1
fi
