#!/usr/bin/env bash
# Batch-audit Forja HTTP movie/TV plugins via crates/engine-js.
#
#   ./scripts/audit-engine-plugins.sh --tmdb=94997 --media=tv --season=1 --episode=1
#   ./scripts/audit-engine-plugins.sh --json --plugin=hdhub4u
#   ./scripts/audit-engine-plugins.sh --assets=DIR   # optional local pack override
#
# Pack URL: FORJA_HQ_PROVIDERS_MANIFEST_URL from repo-root .env (or process env).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
cd "$ROOT/crates"
exec cargo run -q -p engine-js --bin audit-engine-plugins -- "$@"
