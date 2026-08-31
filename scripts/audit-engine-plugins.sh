#!/usr/bin/env bash
# Batch-audit Forja HTTP movie/TV plugins via crates/engine.
#
#   ./scripts/audit-engine-plugins.sh --tmdb=94997 --media=tv --season=1 --episode=1
#   ./scripts/audit-engine-plugins.sh --json --plugin=hdhub4u
#   ./scripts/audit-engine-plugins.sh --assets=DIR   # optional local pack override
#
# Pack source: repo `plugins/providers/manifest.json`, FORJA_HQ_PROVIDERS_MANIFEST_URL,
# or --manifest-url / --assets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
cd "$ROOT/crates"
exec cargo run -q -p engine --bin audit-engine-plugins -- "$@"
