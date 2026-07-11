#!/usr/bin/env bash
# Fail if TV shell boundary APIs leak into feature code.
# See RFC-028 R28-A01 and docs/rfc/028-[draft]-adaptive-shell-profiles.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/apps/forja/lib"

is_allowed() {
  local rel="$1"
  case "$rel" in
    apps/forja/lib/shared/design/src/shell_tokens.dart) return 0 ;;
    apps/forja/lib/shared/design/src/shell_profile.dart) return 0 ;;
    *) return 1 ;;
  esac
}

is_android_tv_allowed() {
  local rel="$1"
  case "$rel" in
    apps/forja/lib/shared/design/src/shell_tokens.dart) return 0 ;;
    *) return 1 ;;
  esac
}

violations=0

while IFS= read -r line; do
  file="${line%%:*}"
  rel="${file#"$ROOT"/}"
  if is_allowed "$rel"; then
    continue
  fi
  echo "UNALLOWED ShellTokens.isTvLayout in $rel"
  echo "  $line"
  violations=1
done < <(
  rg 'ShellTokens\.isTvLayout' "$LIB" \
    --glob '*.dart' \
    --glob '!**/*_test.dart' \
    2>/dev/null | sort -u || true
)

while IFS= read -r line; do
  file="${line%%:*}"
  rel="${file#"$ROOT"/}"
  if is_android_tv_allowed "$rel"; then
    continue
  fi
  echo "UNALLOWED ShellTokens.isAndroidTvDevice in $rel"
  echo "  $line"
  violations=1
done < <(
  rg 'ShellTokens\.isAndroidTvDevice' "$LIB" \
    --glob '*.dart' \
    --glob '!**/*_test.dart' \
    2>/dev/null | sort -u || true
)

width_hits=$(
  rg 'width\s*>\s*900' "$ROOT/apps/forja/lib/features" \
    --glob '*.dart' \
    2>/dev/null | wc -l | tr -d '[:space:]' || true
)
width_hits=${width_hits:-0}
if [[ "$width_hits" -gt 0 ]]; then
  echo "WARN: $width_hits raw width > 900 checks in apps/forja/lib/features (RFC-028 slice 2)"
  rg 'width\s*>\s*900' "$ROOT/apps/forja/lib/features" --glob '*.dart' 2>/dev/null || true
fi

if [[ "$violations" -ne 0 ]]; then
  echo ""
  echo "Use ShellScope.metricsOf / inputPolicyOf / isTvProfile in widgets."
  echo "Use PlatformInfo.isAndroidTv for no-context routes (player, webview, bootstrap)."
  exit 1
fi

echo "check_tv_shell_boundary: OK"
exit 0
