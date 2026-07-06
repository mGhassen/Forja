# 004 — Sync Rust FFI on UI thread (repo-wide audit)

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/02-rust-engine-complete.md))  
**Status:** open — P1 children fixed; parent closes when [009](009-[open]-post-migration-resilience-audit.md) done  
**Area:** `packages/rust`, `packages/api`, `apps/forja`  
**Reported:** 2026-07-06  
**Related:** [001](001-[fixed]-webstreamr-blocks-ui.md) · [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md)

## Summary

Any `RustLib.instance.*` call on the **main Dart isolate** is synchronous from Flutter's point of view. Rust uses `reqwest::blocking` for HTTP — a single call can block the UI for **seconds to minutes**. Spinner stops, back button dead, app feels crashed. **Rust is not crashing**; the UI isolate is starved.

This is a **Dart threading mistake**, not a Rust bug. Rust is doing blocking I/O on the thread Dart gave it.

## Rule (already documented, not enforced)

From [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) and [RFC-009](../rfc/009-rust-ffi.md):

> Sync FFI on UI thread forbidden for calls expected to exceed ~50ms — use `Isolate.run` / `runRustIsolate`.

`packages/rust/lib/src/isolate_runner.dart` exists for this. **Nothing enforces it.**

## Incidents

| Date | Feature | Symptom | Fix |
|------|---------|---------|-----|
| 2026-07-06 | WebStreamr | Resolve freezes player overlay | `runWebstreamrGetStreamsJson` |
| 2026-07-06 | IPTV scrape/channels | Scrape spinner frozen, Reddit loop | `runRustIsolate` + [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) |

## Child issues (open P1)

| # | Title |
|---|-------|
| [005](005-[fixed]-stremio-http-blocks-ui.md) | Stremio addon HTTP |
| [006](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy extractors |
| [007](007-[fixed]-torrent-search-blocks-ui.md) | Torrent search/filter |
| [008](008-[fixed]-ci-enforce-no-sync-ffi.md) | CI enforcement |

## Related (P2+)

| # | Title |
|---|-------|
| [009](009-[open]-post-migration-resilience-audit.md) | Broken-network / cancel UX audit |
| [010](010-[open]-webview-js-extractors-main-thread.md) | WebView / JS extractors |
| [011](011-[fixed]-kisskh-hls-sync-ffi.md) | Kisskh / HLS parse FFI |

## Inventory — production call sites (2026-07-06)

### Fixed (isolate offload)

| File | Calls |
|------|-------|
| `packages/api/lib/playback/webstreamr_service.dart` | `webstreamrGetStreamsJson` via `runWebstreamrGetStreamsJson` |
| `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart` | `httpGetJson`, `httpPostJson`, xtream parse, `iptvProbeStreamJson` |
| `apps/forja/lib/features/iptv/iptv/data/pastesh_decryptor.dart` | `httpGetJson`, `decryptPasteResponse` |

### Still on UI thread — **audit required**

| File | Call | Risk |
|------|------|------|
| `apps/forja/lib/features/iptv/iptv/m3u/m3u_store.dart` | `httpGetJson` | ~~High~~ **fixed** |
| `packages/api/lib/api/stremio_service.dart` | `stremioHttpGet` | **High** — [005](005-[fixed]-stremio-http-blocks-ui.md) |
| `packages/api/lib/playback/vidsrc_extractor.dart` | `resolveVidsrcEmbedJson` | **High** — [006](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) |
| `packages/api/lib/playback/videasy_extractor.dart` | `opensslAesDecryptJson` | Medium — [006](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) |
| `packages/api/lib/api/kisskh_subtitle_decryptor.dart` | `decryptKisskhBody` | Medium — [011](011-[fixed]-kisskh-hls-sync-ffi.md) |
| `packages/rust/lib/src/facade.dart` | `searchTorrentsJson`, `filterTorrentsJson`, `parseM3uJson` | **High** — [007](007-[fixed]-torrent-search-blocks-ui.md) |
| `packages/rust/lib/src/utils/hls_master_parser.dart` | `parseHlsMasterJson` | Low–medium — [011](011-[fixed]-kisskh-hls-sync-ffi.md) |
| `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart` | `decodeXtreamText` | Low (base64 only) |

### UI thread OK (fast / lifecycle)

| File | Call | Why OK |
|------|------|--------|
| `packages/api/lib/playback/torrent_stream_service.dart` | engine start/stop, list files | Short ops; mostly off playback path |
| `packages/api/lib/playback/local_server_service.dart` | `proxyStart` / `proxyStop` | Startup only |
| `packages/api/lib/playback/site111477_proxy.dart` | proxy lifecycle | Startup only |
| `packages/api/lib/api/stremio_service.dart` | JSON parse helpers | CPU-only, small payloads |
| `apps/forja/lib/features/settings/settings_screen.dart` | `version` | Instant |

## Proposed enforcement

### 1. Lint / CI grep (cheap, immediate)

Fail CI if `RustLib.instance.` appears in `apps/forja/lib` or `packages/api/lib` **outside**:
- `packages/rust/lib/src/isolate_runner.dart`
- `**/test/**`
- An explicit allowlist file

### 2. Wrapper policy

All HTTP + scrape + torrent-search FFI must go through `runRustIsolate` (or a typed wrapper in `isolate_runner.dart`). Direct `RustLib.instance.httpGetJson` etc. forbidden in app/api layers.

### 3. Parity test

`packages/rust/test/parity/isolate_runner_test.dart` exists. Add one integration test per high-risk wrapper that asserts the wrapper uses `runRustIsolate` (or run from a non-main isolate in widget test).

### 4. Rust side (performance, not UI fix)

Replace `reqwest::blocking` with async + shared client where possible. **Still** require isolate offload — async Rust doesn't help if Dart calls FFI synchronously.

## Test plan (manual)

For each row in "Still on UI thread":
1. Trigger the feature on a slow/broken network (or airplane mode mid-request).
2. Confirm spinner animates and back/cancel work while waiting.
3. Confirm logs show work continuing without UI jank.

## Acceptance

- [ ] [005](005-[fixed]-stremio-http-blocks-ui.md)–[007](007-[fixed]-torrent-search-blocks-ui.md) closed
- [ ] [008](008-[fixed]-ci-enforce-no-sync-ffi.md) CI grep in place
- [ ] [009](009-[open]-post-migration-resilience-audit.md) checklist completed
- [ ] `.cursor/rules/rust-migration.mdc` references this audit
