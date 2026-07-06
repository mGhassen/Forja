# 001 — WebStreamr extraction blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/02-rust-engine-complete.md))  
**Status:** fixed (Dart isolate offload) — see also [004](004-[open]-sync-ffi-ui-thread-audit.md)  
**Area:** `packages/streaming`, `crates/webstreamr`, `crates/ffi`  
**Reported:** 2026-07-06

## Summary

When WebStreamr resolves streams in the app, the UI freezes for the entire extraction window — loading spinner stops animating, cancel is unresponsive, and the app feels stuck. Extraction eventually succeeds and playback works.

## Root cause

1. **Sync FFI on the main Dart isolate** — `WebStreamrService.getStreams()` calls `RustLib.instance.webstreamrGetStreamsJson()` synchronously. The call does not yield until Rust returns.

   ```dart
   // packages/streaming/lib/src/webstreamr_service.dart
   final raw = RustLib.instance.webstreamrGetStreamsJson(jsonEncode(request));
   ```

2. **Blocking HTTP in Rust** — `crates/webstreamr` uses `reqwest::blocking` with a 20s timeout per request. Extractors chain multiple fetches (e.g. vidsrc = 3 pages, redirect hops, MFP hosts).

3. **All sources run sequentially** — `enabled_sources: []` means all 21 sources are queried one after another in `resolve_streams()`.

## Impact

- Poor UX during Direct Streaming Mode and in-player provider switch to WebStreamr.
- First load can take tens of seconds to minutes depending on network and source responsiveness.
- Loading overlay and cancel button cannot update while the main isolate is blocked.

## Workarounds (testing only)

- Use **Switch Provider → WebStreamr** instead of putting it first in provider order.
- Narrow country codes in **Settings → WebStreamr** to reduce scraper load (does not skip all sources — resolver still iterates all 21 when `enabled_sources` is empty).
- Wait for extraction to finish; app is not crashed.

## Solution (2026-07-06)

Offloaded sync FFI to a worker isolate via shared `runRustIsolate` in `packages/rust/lib/src/isolate_runner.dart`:

1. Added `runWebstreamrGetStreamsJson(requestJson)` — loads the Rust dylib in the worker (`RustLib.initSync(path)`) and calls `webstreamrGetStreamsJson` there.
2. Updated `packages/api/lib/playback/webstreamr_service.dart` to `await runWebstreamrGetStreamsJson(...)` instead of calling `RustLib.instance` on the main isolate.

The UI isolate stays responsive during extraction (spinner animates, navigation works). Rust still uses blocking HTTP internally — that is unchanged.

### Not done (follow-ups)

- Cancellation token from overlay cancel into in-flight Rust work
- Rust-side parallel source resolution / early exit
- Per-source progress callbacks (`Searching vidsrc…`, etc.)

## Related

- `packages/api/lib/playback/webstreamr_service.dart`
- `packages/rust/lib/src/isolate_runner.dart` — `runWebstreamrGetStreamsJson`
- `crates/webstreamr/src/resolver.rs` — `get_streams_json`, `resolve_streams`
- `crates/webstreamr/src/fetcher.rs` — blocking client
- RFC-009 — WebStreamr Rust golden / FFI parity (done; fetch pipeline still blocking)
