#!/usr/bin/env bash
# Fail if production Dart calls RustLib.instance.* outside allowed files.
# See docs/issues/008-[fixed]-ci-enforce-no-sync-ffi.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWLIST="$ROOT/docs/issues/sync-ffi-allowlist.txt"

is_allowed() {
  local file="$1"
  grep -qxF "$file" "$ALLOWLIST" 2>/dev/null || return 1
  return 0
}

violations=0
while IFS= read -r line; do
  file="${line%%:*}"
  rel="${file#"$ROOT"/}"
  if is_allowed "$rel"; then
    continue
  fi
  echo "UNALLOWED RustLib.instance in $rel"
  echo "  $line"
  violations=1
done < <(
  rg 'RustLib\.instance\.' "$ROOT/apps/forja/lib" \
    --glob '*.dart' \
    --glob '!**/*_test.dart' \
    2>/dev/null | sort -u || true
)

# Stale allowlist entries
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  [[ "$rel" =~ ^# ]] && continue
  if ! rg -q 'RustLib\.instance\.' "$ROOT/$rel" 2>/dev/null; then
    echo "STALE ALLOWLIST (remove): $rel"
    violations=1
  fi
done < "$ALLOWLIST"

if [[ "$violations" -ne 0 ]]; then
  echo ""
  echo "Route long FFI through packages/rust/lib/src/isolate_runner.dart"
  echo "or add a justified path to docs/issues/sync-ffi-allowlist.txt"
  exit 1
fi

echo "check_sync_ffi: OK"
exit 0
