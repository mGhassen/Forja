#!/usr/bin/env bash
# cargo wrapper that applies the macOS SDK workaround, then runs cargo in crates/.
# Usage: ./scripts/cargo.sh check --workspace
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/macos_rust_sdk.sh
source "$ROOT/scripts/lib/macos_rust_sdk.sh"
cd "$ROOT/crates"
exec cargo "$@"
