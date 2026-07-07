# 008 — CI must reject sync Rust FFI in app/api layers

**Priority:** P1  
**Severity:** High (regression prevention)  
**Status:** fixed (2026-07-06) — **complete** (not symptom-only; enforcement shipped)  
**Area:** `scripts/check_sync_ffi.sh`, `docs/issues/sync-ffi-allowlist.txt`, `melos.yaml`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[fixed]-sync-ffi-ui-thread-audit.md)

## Status summary

| Layer | Status | Notes |
|-------|--------|-------|
| **CI grep + allowlist** | **fixed** | prevents new sync FFI regressions in app/api |
| **Engine debt** (Rust blocking HTTP) | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |

This issue is **fully fixed**. It enforces the workaround pattern (`isolate_runner`); it does not fix Rust internals.

## Problem (before fix)

Rule "no sync FFI on UI thread" existed in docs but nothing enforced it.

## Fix (done — 2026-07-06)

1. `scripts/check_sync_ffi.sh` — greps `RustLib.instance.` in `apps/forja/lib`, `packages/api/lib`; fails unless allowlisted.
2. `docs/issues/sync-ffi-allowlist.txt` — justified exceptions only.
3. `melos.yaml` → `check-sync-ffi`.

**Verify:** `bash scripts/check_sync_ffi.sh` → `check_sync_ffi: OK`

## Allowlist (current)

| Path | Reason |
|------|--------|
| IPTV files (`iptv_network`, `pastesh_decryptor`, `m3u_store`) | typed runners in `isolate_runner.dart` → `EngineWorkerPool` |
| `settings_screen.dart` | instant FFI |
| `stremio_service.dart` | JSON parse helpers only; HTTP offloaded |
| `torrent_stream_service`, `local_server_service`, `site111477_proxy` | short lifecycle ops |

## Acceptance

- [x] `check_sync_ffi.sh` in CI (via melos)
- [x] Allowlist minimal
- [x] Documented in `.cursor/rules/rust-migration.mdc`
