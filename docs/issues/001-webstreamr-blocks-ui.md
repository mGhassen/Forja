# 001 — WebStreamr extraction blocks the UI thread

**Tracked:** P2-91 ([Phase 2 task](../migration/02-rust-engine-complete.md))  
**Status:** open  
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

## Proposed fix (later)

### Dart (minimum)

- Offload `webstreamrGetStreamsJson` to a background isolate (`Isolate.run` / `compute`).
- Re-init or pass dylib path in the worker isolate (same pattern as `packages/rust/test/helpers/rust_engine.dart`).
- Wire cancellation token so overlay cancel aborts in-flight work where possible.

### Rust (performance)

- Parallelize source resolution (rayon or tokio + async fetcher).
- Early exit once N playable streams are found.
- Optional: honor `enabled_sources` from settings / limit sources by enabled country codes at resolver level.
- Replace `reqwest::blocking` with async + shared client, or document that FFI entry must only be called off the UI thread.

### UX

- Per-source progress callbacks to update loading message (`Searching vidsrc…`, etc.).

## Related

- `packages/streaming/lib/src/webstreamr_service.dart`
- `crates/webstreamr/src/resolver.rs` — `get_streams_json`, `resolve_streams`
- `crates/webstreamr/src/fetcher.rs` — blocking client
- RFC-009 — WebStreamr Rust golden / FFI parity (done; fetch pipeline still blocking)
