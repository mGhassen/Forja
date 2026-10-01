#!/usr/bin/env bash
# RFC-106 — report leftover ds_bridge / compat_exports importers.
# Do NOT rewrite those to the root barrel. App code imports per-file:
#   package:forja_foundation/components/button.dart
#   package:forja_foundation/tokens/forja_shell_colors.dart
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == "--apply" ]]; then
  echo "migrate_foundation_imports: --apply disabled (would recreate hide-list barrels)" >&2
  exit 1
fi

changed=0
while IFS= read -r -d '' file; do
  if grep -q "package:forja/shared/foundation/ds_bridge.dart\|package:forja/shared/foundation/compat_exports.dart" "$file"; then
    changed=$((changed + 1))
    echo "$file"
  fi
done < <(
  find "$ROOT/apps/forja" \( -path '*/.*' -prune \) -o -name '*.dart' -print0 2>/dev/null
)

echo ""
echo "migrate_foundation_imports: $changed leftover bridge/compat importers"
