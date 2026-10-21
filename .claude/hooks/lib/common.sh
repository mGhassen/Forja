#!/usr/bin/env bash
# Shared helpers for Forja Claude Code hooks. Source this file; do not run it.
# Hooks receive one JSON object on stdin. We read it once into HOOK_INPUT.
set -u

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HOOK_INPUT="$(cat 2>/dev/null || true)"

# ---------- JSON in ----------
json_get() {
  # json_get '.tool_input.file_path'  → raw string or empty
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | jq -r "$1 // empty" 2>/dev/null
  else
    printf '%s' "$HOOK_INPUT" | FORJA_JQ_PATH="$1" python3 -I -c '
import json, os, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in [p for p in os.environ["FORJA_JQ_PATH"].split(".") if p]:
    d = d.get(k) if isinstance(d, dict) else None
    if d is None:
        sys.exit(0)
print(d if isinstance(d, str) else json.dumps(d))
'
  fi
}

TOOL_NAME="$(json_get '.tool_name')"
EVENT_NAME="$(json_get '.hook_event_name')"
SESSION_ID="$(json_get '.session_id')"

# ---------- JSON out ----------
json_escape() {
  python3 -I -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"$1"
}

pre_decide() {
  # pre_decide allow|deny|ask "reason"
  local decision="$1" reason="$2"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":%s}}\n' \
    "$decision" "$(json_escape "$reason")"
  exit 0
}

post_context() {
  # Non-blocking note shown to Claude after the tool ran.
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}\n' "$(json_escape "$1")"
  exit 0
}

post_block() {
  # Blocking: Claude sees the reason and must fix it.
  printf '%s\n' "$1" >&2
  exit 2
}

# ---------- grep with ripgrep fallback ----------
# `rg` is a zsh function on this machine and absent from bash PATH. Find the
# binary Claude Code ships, else fall back to grep -E.
_find_rg() {
  if command -v rg >/dev/null 2>&1; then command -v rg; return; fi
  local c
  c="$(command -v claude 2>/dev/null || true)"
  if [[ -n "$c" ]]; then
    local base; base="$(cd "$(dirname "$(readlink "$c" 2>/dev/null || echo "$c")")/.." 2>/dev/null && pwd)"
    local hit; hit="$(ls "$base"/vendor/ripgrep/*/rg 2>/dev/null | head -1)"
    [[ -n "$hit" ]] && { echo "$hit"; return; }
  fi
  ls "$HOME"/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/*/rg 2>/dev/null | head -1
}
RG_BIN="$(_find_rg)"

fgrep_n() {
  # fgrep_n 'regex' path [path…]   → file:line:text (recursive, *.dart etc. handled by caller globs)
  local pat="$1"; shift
  if [[ -n "$RG_BIN" ]]; then
    "$RG_BIN" -n --no-heading --color never -e "$pat" "$@" 2>/dev/null
  else
    grep -rnE -e "$pat" "$@" 2>/dev/null
  fi
}

fgrep_q() {
  local pat="$1"; shift
  if [[ -n "$RG_BIN" ]]; then
    "$RG_BIN" -q -e "$pat" "$@" 2>/dev/null
  else
    grep -rqE -e "$pat" "$@" 2>/dev/null
  fi
}

rel_path() {
  # absolute → repo-relative (unchanged if outside)
  local p="$1"
  case "$p" in
    "$ROOT"/*) printf '%s' "${p#"$ROOT"/}" ;;
    *) printf '%s' "$p" ;;
  esac
}

state_file() {
  # per-session scratch marker
  local dir="${TMPDIR:-/tmp}/forja-claude-hooks"
  mkdir -p "$dir" 2>/dev/null
  printf '%s/%s.%s' "$dir" "${SESSION_ID:-nosession}" "$1"
}
