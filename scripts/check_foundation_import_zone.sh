#!/usr/bin/env bash
# Fail if zone-A design-system layers import the Flutter host or Riverpod.
# See RFC-106 R106-A13 / G12.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/packages/forja_foundation/lib"

zones=(
  components
  primitives
  widgets
  tokens
  theme
)

violations=0

for zone in "${zones[@]}"; do
  dir="$PKG/$zone"
  if [[ ! -d "$dir" ]]; then
    echo "MISSING zone dir: $dir"
    violations=1
    continue
  fi
  while IFS= read -r line; do
    echo "FORBIDDEN package:forja/ in $line"
    violations=1
  done < <(
    rg -n 'package:forja/' "$dir" --glob '*.dart' 2>/dev/null || true
  )
  while IFS= read -r line; do
    echo "FORBIDDEN flutter_riverpod in $line"
    violations=1
  done < <(
    rg -n 'flutter_riverpod' "$dir" --glob '*.dart' 2>/dev/null || true
  )
done

if [[ "$violations" -ne 0 ]]; then
  echo ""
  echo "packages/forja_foundation zone A (components/primitives/widgets/tokens/theme)"
  echo "must not import package:forja/ or flutter_riverpod."
  exit 1
fi

echo "check_foundation_import_zone: OK"
exit 0
