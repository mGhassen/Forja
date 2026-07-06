# 015 — Rust blocking HTTP and sync resolve engine debt

**Priority:** P2  
**Severity:** Medium (perf, resource use, cancel waste — UI freeze workaround shipped)  
**Status:** open  
**Area:** `crates/webstreamr`, `crates/stremio-core`, `crates/stream-core`, `crates/scrapers`, `crates/ffi`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)  
**Related:** [009](009-[workaround]-post-migration-resilience-audit.md) (cancel-abort UX)

## Summary

Workarounds in [001](001-[workaround]-webstreamr-blocks-ui.md), [005](005-[workaround]-stremio-http-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md), [011](011-[workaround]-kisskh-hls-sync-ffi.md) offloaded sync FFI to worker isolates. **The UI no longer freezes**, but Rust still uses blocking I/O internally. Every long call spawns a worker isolate, work cannot be aborted mid-flight in Rust, and resolve stays slow.

This issue tracks the **root / engine fix**. Do not delete — symptom-fixed issues point here.

## Root cause (engine)

| Crate | Problem |
|-------|---------|
| `webstreamr` | `reqwest::blocking`, 21 sources sequential, 20s timeout per hop |
| `stremio-core` | blocking HTTP for addon fetches |
| `stream-core` | multi-page blocking resolve (vidsrc chain) |
| `scrapers` | torrent search (partially async; FFI entry still sync) |

Dart `Isolate.run` only moves the block off the UI thread. It does not fix engine architecture.

## Root fix (required)

1. **Async HTTP** — replace `reqwest::blocking` with async client + shared connection pool in affected crates.
2. **Parallel resolve** — webstreamr: parallel source queries, early exit when N streams found; torrent: already parallel in Rust — verify FFI boundary.
3. **Cancellable jobs** — FFI job API or cancellation token so overlay Cancel stops in-flight Rust work (see also [009](009-[workaround]-post-migration-resilience-audit.md)).
4. **Optional:** async job API from Dart (poll/cancel) instead of one sync FFI call per operation — reduces isolate spawn churn.

**Note:** Even after async Rust, Dart must still use `Isolate.run` or non-blocking FFI — sync FFI on UI thread stays forbidden ([ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) R5).

## Per-feature scope

| Symptom issue | Engine work here |
|---------------|------------------|
| [001](001-[workaround]-webstreamr-blocks-ui.md) | `crates/webstreamr` async fetcher, parallel `resolve_streams`, early exit |
| [005](005-[workaround]-stremio-http-blocks-ui.md) | `crates/stremio-core` async HTTP |
| [006](006-[workaround]-vidsrc-videasy-extractors-blocks-ui.md) | `crates/stream-core` async resolve chain; cancel token |
| [007](007-[workaround]-torrent-search-blocks-ui.md) | verify scrapers FFI + reduce isolate churn |
| [011](011-[workaround]-kisskh-hls-sync-ffi.md) | large payload parse in Rust without per-call isolate spawn (optional) |

## Acceptance

- [x] `webstreamr` uses async HTTP (`fetcher.rs` — shared `reqwest::Client` + tokio runtime; sync API wraps `block_on`)
- [x] `webstreamr` primary sources resolve in parallel with early exit (`resolver.rs` — rayon, 8 playable URLs)
- [x] `stremio-core` uses shared async HTTP client + runtime (no per-call `Runtime::new()`)
- [ ] Cancel from host aborts in-flight resolve in Rust (with [009](009-[workaround]-post-migration-resilience-audit.md))
- [ ] Document in [RFC-009](../rfc/009-rust-ffi.md) threading section — remove "Future:" placeholder
- [ ] Profile: long resolve no longer spawns new isolate per call (if job API adopted)

## If symptom-fixed issues are deleted

This file is the **only** place that lists the engine work still owed. Keep it until root fix ships.
