#!/usr/bin/env bash
# Run a long command while printing a line every 60s so CI logs do not look hung
# during silent MSVC / Xcode / cargo release compiles.
set -euo pipefail

LABEL="${1:?usage: ci_with_heartbeat.sh <label> <command...>}"
shift

(
  while true; do
    sleep 60
    echo "[ci] ${LABEL} still running… $(date -u +%H:%M:%S) UTC"
  done
) &
HB_PID=$!

cleanup() {
  kill "$HB_PID" 2>/dev/null || true
  wait "$HB_PID" 2>/dev/null || true
}
trap cleanup EXIT

"$@"
