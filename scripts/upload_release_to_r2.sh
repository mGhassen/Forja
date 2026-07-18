#!/usr/bin/env bash
# Thin wrapper — see upload_release_to_r2.py
set -euo pipefail
exec "$(dirname "$0")/upload_release_to_r2.py" "$@"
