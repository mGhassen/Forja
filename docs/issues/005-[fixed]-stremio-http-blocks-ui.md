# 005 — Stremio addon HTTP blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `packages/api/lib/api/stremio_service.dart`, `crates/stremio-core`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Summary

Stremio catalog/meta/stream fetches call `RustLib.instance.stremioHttpGet()` **synchronously on the main isolate**. Addon timeouts (15s default) freeze the UI — browse grids, detail screens, and stream pickers stop repainting.

## Root cause

```dart
// packages/api/lib/api/stremio_service.dart
final raw = RustLib.instance.stremioHttpGet(url, timeoutSecs: timeoutSecs);
```

Rust uses blocking HTTP. Dart `async` on the caller does not yield during the FFI call.

## Impact

- Stremio addon browse feels stuck on slow/dead addons
- Back navigation unresponsive during fetch
- Same symptom class as [001](001-[fixed]-webstreamr-blocks-ui.md) and IPTV scrape freeze

## Solution (2026-07-06)

1. Added `runStremioHttpGet(url, {timeoutSecs})` in `packages/rust/lib/src/isolate_runner.dart` — runs `RustLib.instance.stremioHttpGet` inside `runRustIsolate`.
2. Updated `packages/api/lib/api/stremio_service.dart` to `await runStremioHttpGet(...)` for all addon HTTP fetches.

JSON parse helpers (`parseStremioManifestJson`, etc.) remain on the UI thread — payloads are small and CPU-only. `stremio_service.dart` is allowlisted in `docs/issues/sync-ffi-allowlist.txt` only for those parse helpers, not for HTTP.

## Acceptance

- [x] `stremioHttpGet` never called on main isolate from production code
- [ ] Manual test: slow addon URL — spinner animates, back works
- [ ] [004](004-[open]-sync-ffi-ui-thread-audit.md) inventory row marked fixed
