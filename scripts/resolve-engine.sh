#!/usr/bin/env bash
# Race providers via crates/resolver-engine (same path as the app).
#
#   ./scripts/resolve-engine --tmdb=1083381
#   ./scripts/resolve-engine -p webstreamr --tmdb=1083381
#   ./scripts/resolve-engine --native-only --tmdb=1705729
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"
exec cargo run -q -p resolver-engine --bin resolve-engine -- "$@"
