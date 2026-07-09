#!/usr/bin/env bash
set -euo pipefail

# Verify release build contains Rust engine + main binary before packaging.
# Usage: verify_installer_payload.sh macos|windows|linux

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/forja"
PLATFORM="${1:?usage: verify_installer_payload.sh macos|windows|linux}"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "error: missing required file: $1" >&2
    exit 1
  fi
  echo "ok: $1"
}

case "$PLATFORM" in
  macos)
    APP_BUNDLE="$APP/build/macos/Build/Products/Release/forja.app"
    require_file "$APP_BUNDLE/Contents/MacOS/forja"
    require_file "$APP_BUNDLE/Contents/Frameworks/libffi.dylib"
    ;;
  windows)
    RELEASE="$APP/build/windows/x64/runner/Release"
    require_file "$RELEASE/forja.exe"
    require_file "$RELEASE/ffi.dll"
    ;;
  linux)
    BUNDLE="$APP/build/linux/x64/release/bundle"
    require_file "$BUNDLE/forja"
    require_file "$BUNDLE/lib/libffi.so"
    ;;
  *)
    echo "unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac

echo "installer payload verified for $PLATFORM"
