#!/usr/bin/env bash
# Run mobile magnet E2E on a connected Android/iOS device or emulator.
#
# Usage:
#   ./scripts/run_mobile_magnet_e2e.sh [device-id]
#   TORRENT_E2E=1 ./scripts/run_mobile_magnet_e2e.sh   # full magnet → HTTP (slow)
#
# Prerequisites:
#   - Flutter SDK, device/emulator running (`flutter devices`)
#   - ./scripts/build_rust_mobile.sh for the target platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/apps/forja"

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
try:
    devs = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for d in devs:
    if d.get('emulator') or d.get('platformType') in ('android', 'ios'):
        print(d['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null || true)"
fi

if [[ -z "$DEVICE" ]]; then
  echo "error: no Android/iOS device or emulator found." >&2
  echo "  Start an emulator or connect a device, then retry." >&2
  echo "  Or pass device id: $0 <device-id>" >&2
  exit 1
fi

echo "==> Building mobile Rust FFI (android + ios when on macOS)"
"$ROOT/scripts/build_rust_mobile.sh" all 2>/dev/null || "$ROOT/scripts/build_rust_mobile.sh" android

echo "==> Running mobile_magnet_e2e_test.dart on $DEVICE"
flutter pub get
flutter test test/mobile_magnet_e2e_test.dart -d "$DEVICE"

echo "mobile_magnet_e2e: OK"
