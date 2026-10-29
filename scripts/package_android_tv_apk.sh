#!/usr/bin/env bash
set -euo pipefail

# Kept for old callers. Use package_android_apk.sh <tv|mobile> <version> [abis].
# Usage: package_android_tv_apk.sh <version> [arm64|armeabi-v7a]...
exec "$(cd "$(dirname "$0")" && pwd)/package_android_apk.sh" tv "$@"
