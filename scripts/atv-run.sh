#!/usr/bin/env bash
# Launch Forja on Android TV with Chromium --disable-gpu (emulator/dev).
# Required for embedded WebViews (trailers, live) on GLES-broken ATV emulators.
set -euo pipefail

DEVICE="${1:-emulator-5554}"
shift || true

ADB="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}/platform-tools/adb"
FLAG_FILE="/data/local/tmp/webview-command-line"
FLAGS="_ --disable-gpu --disable-gpu-rasterization"

"$ADB" -s "$DEVICE" shell "echo '$FLAGS' > $FLAG_FILE" 2>/dev/null || {
  echo "Warning: could not write $FLAG_FILE (need writable /data/local/tmp on device)" >&2
}

"$ADB" -s "$DEVICE" shell am force-stop com.forja.app 2>/dev/null || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/apps/forja"
exec flutter run -d "$DEVICE" "$@"
