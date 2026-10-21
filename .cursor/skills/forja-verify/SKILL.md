---
name: forja-verify
description: >-
  Run Forja's verification ladder (boundary scripts, foundation analyze/test,
  app analyze, targeted app tests, cargo, pnpm) with the known-bad baseline and
  report what passed, failed, or could not run. Use after any code change,
  before claiming done, or when the user says verify, test, check, analyze.
argument-hint: "[dart|rust|web|all] [path/to/x_test.dart …]"
allowed-tools: Bash, Read, Grep, Glob
---

# /forja-verify

Scope requested: `$ARGUMENTS` (empty = infer from `git status`).

Toolchain on this machine right now:

!`for t in flutter dart cargo melos pnpm node; do printf '%s=%s ' "$t" "$(command -v $t >/dev/null 2>&1 && echo yes || echo MISSING)"; done; echo`

Changed files:

!`git status --porcelain | head -40`

## Ladder

Run in order; skip steps whose tool is MISSING and say so. Never claim a step passed that you did not run.

| # | When | Command | Expect |
|---|------|---------|--------|
| 1 | always | `export PATH="$(dirname "$(ls ~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/*/rg \| head -1)"):$PATH"` then `./scripts/check_tv_shell_boundary.sh; ./scripts/check_foundation_import_zone.sh; ./scripts/check_foundation_shim_alive.sh; ./scripts/check_sync_ffi.sh` | known drift on main: import-zone expects deleted `primitives/` `theme/` dirs; sync-ffi has stale allowlist rows; tv-boundary reports pre-existing hits. Only **new** hits in your changed files count. |
| 2 | `packages/forja_foundation` changed | `cd packages/forja_foundation && flutter analyze && flutter test` | ~2 s + ~2 s, green |
| 3 | any Dart changed | `cd apps/forja && flutter analyze` | ~6 s, no errors |
| 4 | app Dart changed | `cd apps/forja && flutter test test/<file>_test.dart` for each test touching the diff | targeted only; full suite is 10+ min with known-bad `catalog_protocol_test`, `sources_panel_filters_nuvio_lazy_test`, `forja_logo_halo_pixels_test` (timeout); pack-dependent tests need `../forja-packs` or `FORJA_PACKS_ROOT` |
| 5 | `crates/` or `packages/rust` changed | `source scripts/lib/macos_rust_sdk.sh; cd crates && cargo clippy --workspace && cargo test --workspace && cargo test -p utils --test golden && cargo test -p iptv --test golden_m3u; cd ../packages/rust && flutter test` | green |
| 6 | `apps/web` changed | `cd apps/web && pnpm lint && pnpm build` | green |
| 7 | a failure looks unrelated | `git worktree add --detach /tmp/forja-base HEAD` and rerun there (never `git stash`) | same failure on base = pre-existing |

Delegate steps 2–7 to the `forja-qa` subagent when more than two steps apply; it returns the table below.

## Report

```
## Toolchain
## Results  (| Step | Command | Result |)
## Failures caused by this change
## Pre-existing / environmental
## Not run (and why)
## Verdict: verified | partially verified (…) | could not verify
```

Quote failing output verbatim. "Should work" is banned.
