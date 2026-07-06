# 004 — Sync Rust FFI on UI thread (repo-wide audit)

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/02-rust-engine-complete.md))  
**Status:** open — Dart workarounds shipped; engine root fix [015](015-[open]-rust-blocking-http-engine-debt.md); parent closes when [015](015-[open]-rust-blocking-http-engine-debt.md) + [009](009-[open]-post-migration-resilience-audit.md) done  
**Area:** `packages/rust`, `packages/api`, `apps/forja`  
**Reported:** 2026-07-06

## Summary

Sync `RustLib.instance.*` on the **main Dart isolate** blocked the UI for seconds to minutes. **Workarounds** (isolate offload) shipped for P1 call sites. **Root engine fix** (async Rust, parallel resolve, cancel-abort) is **open** — [015](015-[open]-rust-blocking-http-engine-debt.md).

## Two layers (do not conflate)

| Layer | Status | Where tracked |
|-------|--------|---------------|
| Symptom — UI thread must not block | **workaround** (P1 call sites) | [001](001-[workaround]-webstreamr-blocks-ui.md), [005](005-[workaround]-stremio-http-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md), [011](011-[workaround]-kisskh-hls-sync-ffi.md); CI [008](008-[fixed]-ci-enforce-no-sync-ffi.md) **fixed** |
| Root — blocking HTTP / sync resolve in `crates/*` | **open** | [015](015-[open]-rust-blocking-http-engine-debt.md) |
| Cancel / resilience | **open** | [009](009-[open]-post-migration-resilience-audit.md) |

Isolate offload stops UI freeze but is a **workaround** — root engine fix is [015](015-[open]-rust-blocking-http-engine-debt.md).

## Rule

From [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) and [RFC-009](../rfc/009-rust-ffi.md):

> Sync FFI on UI thread forbidden for calls expected to exceed ~50ms — use `Isolate.run` / `runRustIsolate`.

Enforced by [008](008-[fixed]-ci-enforce-no-sync-ffi.md) (`check_sync_ffi.sh`).

## Child issues

| # | Title | Symptom | Root |
|---|-------|---------|------|
| [001](001-[workaround]-webstreamr-blocks-ui.md) | WebStreamr | workaround | open → [015](015-[open]-rust-blocking-http-engine-debt.md) |
| [005](005-[workaround]-stremio-http-blocks-ui.md) | Stremio HTTP | workaround | open → [015](015-[open]-rust-blocking-http-engine-debt.md) |
| [006](006-[workaround]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy | workaround | open → [015](015-[open]-rust-blocking-http-engine-debt.md) |
| [007](007-[workaround]-torrent-search-blocks-ui.md) | Torrent search | workaround | open → [015](015-[open]-rust-blocking-http-engine-debt.md) |
| [008](008-[fixed]-ci-enforce-no-sync-ffi.md) | CI enforcement | **fixed** | — |
| [011](011-[workaround]-kisskh-hls-sync-ffi.md) | Kisskh / HLS / M3U | workaround | open → [015](015-[open]-rust-blocking-http-engine-debt.md) |
| [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | Reddit cursor loop | **fixed** | — |

## Inventory — production call sites (2026-07-06, verified)

### Workaround shipped — isolate offload

| File | Calls |
|------|-------|
| `packages/api/lib/playback/webstreamr_service.dart` | `runWebstreamrGetStreamsJson` |
| `packages/api/lib/api/stremio_service.dart` | `runStremioHttpGet` (HTTP); parse helpers on UI — OK |
| `packages/api/lib/playback/vidsrc_extractor.dart` | `runResolveVidsrcEmbedJson` |
| `packages/api/lib/playback/videasy_extractor.dart` | `runOpensslAesDecryptJson` |
| `packages/api/lib/api/kisskh_subtitle_decryptor.dart` | `runDecryptKisskhBody` |
| `packages/rust/lib/src/facade.dart` | `runSearchTorrentsJson`, `runFilterTorrentsJson`, `runSortTorrentsJson`, `runParseM3uJson` |
| `packages/rust/lib/src/utils/hls_master_parser.dart` | `runParseHlsMasterJson` |
| `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart` | HTTP/xtream inside `runRustIsolate`; `decodeXtreamText` waived |
| `apps/forja/lib/features/iptv/iptv/data/pastesh_decryptor.dart` | inside `runRustIsolate` |
| `apps/forja/lib/features/iptv/iptv/m3u/m3u_store.dart` | inside `runRustIsolate` |

### UI thread OK (fast / lifecycle / allowlisted)

| File | Call | Why OK |
|------|------|--------|
| `torrent_stream_service.dart` | engine start/stop, list files | Short lifecycle ops |
| `local_server_service.dart` | proxy start/stop | Startup only |
| `site111477_proxy.dart` | proxy lifecycle | Startup only |
| `stremio_service.dart` | JSON parse helpers | CPU-only, small payloads |
| `settings_screen.dart` | `version` | Instant |
| `iptv_network.dart` | `decodeXtreamText` | Tiny base64 decode |

## Root fix (open)

[015](015-[open]-rust-blocking-http-engine-debt.md) — async HTTP, parallel resolve, cancel-abort, reduce isolate churn.

## Acceptance

- [x] [005](005-[workaround]-stremio-http-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md) workaround shipped
- [x] [008](008-[fixed]-ci-enforce-no-sync-ffi.md) CI grep in place
- [ ] [015](015-[open]-rust-blocking-http-engine-debt.md) engine root fix
- [ ] [009](009-[open]-post-migration-resilience-audit.md) checklist completed
