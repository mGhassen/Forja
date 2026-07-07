# 004 — Sync Rust FFI on UI thread (repo-wide audit)

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/fixed/02-[fixed]-rust-engine-complete.md))  
**Status:** fixed  
**Area:** `packages/rust`, `packages/api`, `apps/forja`, `crates/*`  
**Reported:** 2026-07-06  
**Fixed:** 2026-07-06 (engine root: [015](015-[fixed]-rust-blocking-http-engine-debt.md))
## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** |
| **Backlog** | [0.4.1](../backlog/done/0.4.1-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---


## Summary

Sync `RustLib.instance.*` on the **main Dart isolate** blocked the UI for seconds to minutes. **Symptom workarounds** (isolate offload) shipped for P1 call sites. **Root engine fix** shipped in [015](015-[fixed]-rust-blocking-http-engine-debt.md).

## Two layers

| Layer | Status | Where tracked |
|-------|--------|---------------|
| Symptom — UI thread must not block | **fixed** | [001](001-[fixed]-webstreamr-blocks-ui.md)–[007](007-[fixed]-torrent-search-blocks-ui.md), [011](011-[fixed]-kisskh-hls-sync-ffi.md); CI [008](008-[fixed]-ci-enforce-no-sync-ffi.md) |
| Root — blocking HTTP / sync resolve in `crates/*` | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| Cancel / resilience | **fixed** | [009](009-[fixed]-post-migration-resilience-audit.md) |

Isolate offload remains required (R5). It is no longer masking blocking HTTP inside Rust.

## Rule

From [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) and [RFC-009](../rfc/fixed/009-[fixed]-rust-ffi.md):

> Sync FFI on UI thread forbidden for calls expected to exceed ~50ms — use `Isolate.run` / `runRustIsolate`.

Enforced by [008](008-[fixed]-ci-enforce-no-sync-ffi.md) (`check_sync_ffi.sh`).

## Child issues

| # | Title | Symptom | Root |
|---|-------|---------|------|
| [001](001-[fixed]-webstreamr-blocks-ui.md) | WebStreamr | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [005](005-[fixed]-stremio-http-blocks-ui.md) | Stremio HTTP | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [006](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [007](007-[fixed]-torrent-search-blocks-ui.md) | Torrent search | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [008](008-[fixed]-ci-enforce-no-sync-ffi.md) | CI enforcement | **fixed** | — |
| [011](011-[fixed]-kisskh-hls-sync-ffi.md) | Kisskh / HLS / M3U | **fixed** | `EngineWorkerPool` |
| [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | Reddit cursor loop | **fixed** | — |

## Acceptance

- [x] [005](005-[fixed]-stremio-http-blocks-ui.md)–[007](007-[fixed]-torrent-search-blocks-ui.md) workaround shipped
- [x] [008](008-[fixed]-ci-enforce-no-sync-ffi.md) CI grep in place
- [x] [015](015-[fixed]-rust-blocking-http-engine-debt.md) engine root fix (async HTTP, parallel resolve, cancel-abort)
- [x] [009](009-[fixed]-post-migration-resilience-audit.md) host cancel UX workaround shipped; Rust abort wired in 015
