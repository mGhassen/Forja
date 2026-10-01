#!/usr/bin/env bash
# RFC-106 G14-E — shim tree must stay gone. Fails if it is resurrected
# or if Dart still imports package:forja/shared/foundation/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/apps/forja/lib/shared/foundation"

if [[ -d "$BASE" ]]; then
  echo "FATAL: $BASE still exists — delete the stub tree; do not restore it."
  echo "See packages/forja_foundation/MIGRATION.md"
  exit 1
fi

if rg -q "package:forja/shared/foundation/" "$ROOT/apps/forja" --glob '*.dart'; then
  echo "FATAL: Dart still imports package:forja/shared/foundation/"
  rg "package:forja/shared/foundation/" "$ROOT/apps/forja" --glob '*.dart'
  exit 1
fi

echo "check_foundation_shim_alive: OK (tree gone, no dart imports)"
exit 0
