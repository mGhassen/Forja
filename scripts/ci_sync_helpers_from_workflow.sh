#!/usr/bin/env bash
# Existing-tag release jobs checkout an older tree. Pull CI helpers from the
# workflow commit when missing so cache/setup steps still work.
set -euo pipefail

SHA="${1:?usage: ci_sync_helpers_from_workflow.sh <github.sha>}"

paths=(
  .github/actions/setup-forja-build
  scripts/ci_with_heartbeat.sh
)

missing=()
for p in "${paths[@]}"; do
  if [[ ! -e "$p" ]]; then
    missing+=("$p")
  fi
done

if ((${#missing[@]} == 0)); then
  chmod +x scripts/ci_with_heartbeat.sh
  exit 0
fi

echo "CI helpers missing on checkout; fetching from workflow ref ${SHA}: ${missing[*]}"
git fetch --depth=1 origin "${SHA}"
git checkout "${SHA}" -- "${missing[@]}"
chmod +x scripts/ci_with_heartbeat.sh
