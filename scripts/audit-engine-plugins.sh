#!/usr/bin/env bash
# Batch-audit Forja HTTP movie/TV plugins via crates/engine-js.
#
#   ./scripts/audit-engine-plugins.sh --tmdb=94997 --media=tv --season=1 --episode=1
#   ./scripts/audit-engine-plugins.sh --json --plugin=hdhub4u
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/crates"
exec cargo run -q -p engine-js --bin audit-engine-plugins -- "$@"
