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
flutter build macos --release
echo "Built: $APP/build/macos/Build/Products/Release/forja.app"
