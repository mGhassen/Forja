# 004 — Sync Rust FFI on UI thread (repo-wide audit)

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/02-rust-engine-complete.md))  
**Status:** fixed  
**Area:** `packages/rust`, `packages/api`, `apps/forja`, `crates/*`  
**Reported:** 2026-07-06  
**Fixed:** 2026-07-06 (engine root: [015](015-[fixed]-rust-blocking-http-engine-debt.md))

## Summary

Sync `RustLib.instance.*` on the **main Dart isolate** blocked the UI for seconds to minutes. **Symptom workarounds** (isolate offload) shipped for P1 call sites. **Root engine fix** shipped in [015](015-[fixed]-rust-blocking-http-engine-debt.md).

## Two layers

| Layer | Status | Where tracked |
|-------|--------|---------------|
| Symptom — UI thread must not block | **workaround** (P1 call sites) | [001](001-[workaround]-webstreamr-blocks-ui.md), [005](005-[workaround]-stremio-http-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md), [011](011-[workaround]-kisskh-hls-sync-ffi.md); CI [008](008-[fixed]-ci-enforce-no-sync-ffi.md) **fixed** |
| Root — blocking HTTP / sync resolve in `crates/*` | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| Cancel / resilience (host UX) | **workaround** + Rust abort | [009](009-[workaround]-post-migration-resilience-audit.md); Rust cancel in 015 |

Isolate offload remains required (R5). It is no longer masking blocking HTTP inside Rust.

## Rule

From [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) and [RFC-009](../rfc/009-rust-ffi.md):

> Sync FFI on UI thread forbidden for calls expected to exceed ~50ms — use `Isolate.run` / `runRustIsolate`.

Enforced by [008](008-[fixed]-ci-enforce-no-sync-ffi.md) (`check_sync_ffi.sh`).

## Child issues

| # | Title | Symptom | Root |
|---|-------|---------|------|
| [001](001-[workaround]-webstreamr-blocks-ui.md) | WebStreamr | workaround | **fixed** → [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [005](005-[workaround]-stremio-http-blocks-ui.md) | Stremio HTTP | workaround | **fixed** → [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [006](006-[workaround]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy | workaround | **fixed** → [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [007](007-[workaround]-torrent-search-blocks-ui.md) | Torrent search | workaround | **fixed** → [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| [008](008-[fixed]-ci-enforce-no-sync-ffi.md) | CI enforcement | **fixed** | — |
| [011](011-[workaround]-kisskh-hls-sync-ffi.md) | Kisskh / HLS / M3U | workaround | partial — large payload parse; job API deferred |
| [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | Reddit cursor loop | **fixed** | — |

## Acceptance

- [x] [005](005-[workaround]-stremio-http-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md) workaround shipped
- [x] [008](008-[fixed]-ci-enforce-no-sync-ffi.md) CI grep in place
- [x] [015](015-[fixed]-rust-blocking-http-engine-debt.md) engine root fix (async HTTP, parallel resolve, cancel-abort)
- [x] [009](009-[workaround]-post-migration-resilience-audit.md) host cancel UX workaround shipped; Rust abort wired in 015
