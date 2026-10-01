#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/forja"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found in PATH. Install Flutter and retry."
  exit 1
fi

cd "$APP"
flutter pub get
if [ ! -d macos ]; then
  flutter create --platforms=macos .
fi
# Match CI: compile unsigned, then deep ad-hoc sign (no paid Apple cert).
FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO flutter build macos --release
"$ROOT/scripts/codesign_macos_adhoc.sh"
echo "Built: $APP/build/macos/Build/Products/Release/forja.app"
