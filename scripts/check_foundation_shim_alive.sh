#!/usr/bin/env bash
# RFC-106 G14-G — shim death forbidden until QA (G14-E).
# Fails if required re-export stubs under apps/forja/lib/shared/foundation are missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/apps/forja/lib/shared/foundation"

required=(
  "foundation.dart"
  "compat_exports.dart"
  "ds_bridge.dart"
  "protocol/protocol.dart"
  "lib/match_event.dart"
  "components/layout/kit_types.dart"
)

missing=0

if [[ ! -d "$BASE" ]]; then
  echo "FATAL: shared/foundation tree deleted — shim death only after G14-E QA."
  echo "See docs/rfc/106-invariants.md"
  exit 1
fi

for rel in "${required[@]}"; do
  path="$BASE/$rel"
  if [[ ! -f "$path" ]]; then
    echo "MISSING shim: $path"
    missing=1
    continue
  fi
  # Stubs must still export something (re-export or library).
  if ! rg -q '^export |^library' "$path"; then
    echo "EMPTY/invalid shim (no export/library): $path"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo ""
  echo "check_foundation_shim_alive: FAIL — restore stubs; do not delete foundation until QA."
  exit 1
fi

echo "check_foundation_shim_alive: OK"
exit 0
