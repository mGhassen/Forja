#!/usr/bin/env bash
set -euo pipefail

# Rename split-per-abi release APKs of one Android flavor to Forja release
# asset names.
# Usage: package_android_apk.sh <tv|mobile> <version> [arm64|armeabi-v7a]...
#   No ABI args → both (local release default).
# Input (flutter build apk --release --split-per-abi --flavor <flavor>):
#   apps/forja/build/app/outputs/flutter-apk/app-<abi>-<flavor>-release.apk
# Output (per selected ABI):
#   dist/Forja-<version>-android-<flavor>-arm64.apk
#   dist/Forja-<version>-android-<flavor>-armeabi-v7a.apk

USAGE="usage: package_android_apk.sh <tv|mobile> <version> [arm64|armeabi-v7a]..."
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLAVOR="${1:?$USAGE}"
VERSION="${2:?$USAGE}"
shift 2
APK_DIR="$ROOT/apps/forja/build/app/outputs/flutter-apk"
DIST="$ROOT/dist"

case "$FLAVOR" in
  tv|mobile) ;;
  *)
    echo "error: unknown flavor '$FLAVOR' (want tv or mobile)" >&2
    exit 1
    ;;
esac

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

find_aapt() {
  local aapt bt
  aapt="$(command -v aapt 2>/dev/null || true)"
  if [[ -z "$aapt" ]]; then
    for bt in \
      "${ANDROID_HOME:-}${ANDROID_HOME:+/}build-tools"/*/aapt \
      "${ANDROID_SDK_ROOT:-}${ANDROID_SDK_ROOT:+/}build-tools"/*/aapt \
      "$HOME/Library/Android/sdk/build-tools"/*/aapt; do
      [[ -x "$bt" ]] || continue
      aapt="$bt"
    done
  fi
  printf '%s' "$aapt"
}

# Refuse packaging a stale flutter-apk left over from a failed rebuild, and a
# TV/mobile mix-up (only the TV flavor carries the leanback launcher entry).
verify_badging() {
  local apk="$1"
  local expect="$2"
  local aapt badging got
  aapt="$(find_aapt)"
  if [[ -z "$aapt" ]]; then
    echo "error: aapt not found — cannot verify versionName in $apk" >&2
    exit 1
  fi
  badging="$("$aapt" dump badging "$apk")"
  got="$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<<"$badging" | head -1)"
  if [[ "$got" != "$expect" ]]; then
    echo "error: $apk versionName='$got' (expected '$expect') — stale APK from a failed build?" >&2
    exit 1
  fi
  if grep -Fq "leanback-launchable-activity" <<<"$badging"; then
    if [[ "$FLAVOR" != tv ]]; then
      echo "error: $apk has a leanback launcher entry but flavor is '$FLAVOR'" >&2
      exit 1
    fi
  elif [[ "$FLAVOR" == tv ]]; then
    echo "error: $apk has no leanback launcher entry — not a TV flavor build?" >&2
    exit 1
  fi
}

mkdir -p "$DIST"
created=0

for abi in "$@"; do
  case "$abi" in
    arm64|arm64-v8a)
      gradle_abi="arm64-v8a"
      asset_abi="arm64"
      ;;
    armeabi-v7a|v7a|arm)
      gradle_abi="armeabi-v7a"
      asset_abi="armeabi-v7a"
      ;;
    *)
      echo "error: unknown ABI '$abi' (want arm64 or armeabi-v7a)" >&2
      exit 1
      ;;
  esac
  lib="lib/${gradle_abi}/libffi.so"
  out="$DIST/Forja-${VERSION}-android-${FLAVOR}-${asset_abi}.apk"

  # Flutter's Gradle plugin names flavored splits app-<abi>-<flavor>-<mode>.apk;
  # accept AGP's app-<flavor>-<abi>-<mode>.apk order too.
  src=""
  for candidate in \
    "$APK_DIR/app-${gradle_abi}-${FLAVOR}-release.apk" \
    "$APK_DIR/app-${FLAVOR}-${gradle_abi}-release.apk"; do
    if [[ -f "$candidate" ]]; then
      src="$candidate"
      break
    fi
  done
  if [[ -z "$src" ]]; then
    echo "error: missing $APK_DIR/app-${gradle_abi}-${FLAVOR}-release.apk — run flutter build apk --release --split-per-abi --flavor ${FLAVOR} first" >&2
    exit 1
  fi

  # Source mtime must be newer than a few minutes before this script started —
  # catches "flutter build failed → copy yesterday's APK" releases.
  if [[ "$(uname -s)" == Darwin ]]; then
    src_mtime="$(stat -f '%m' "$src")"
  else
    src_mtime="$(stat -c '%Y' "$src")"
  fi
  now="$(date +%s)"
  if (( now - src_mtime > 7200 )); then
    echo "error: $src is older than 2h (mtime $(date -r "$src_mtime" 2>/dev/null || date -d "@$src_mtime")) — rebuild before packaging" >&2
    exit 1
  fi

  cp -f "$src" "$out"
  verify_libffi "$out" "$lib"
  verify_badging "$out" "$VERSION"
  echo "Created $out"
  created=$((created + 1))
done

if [[ "$created" -eq 0 ]]; then
  echo "error: no APKs packaged" >&2
  exit 1
fi
