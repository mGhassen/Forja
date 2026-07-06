# 006 — Vidsrc / Videasy extractors block the UI thread

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `packages/api/lib/playback/vidsrc_extractor.dart`, `videasy_extractor.dart`, `crates/stream-core`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Summary

Direct-streaming provider resolution calls sync Rust FFI on the UI thread. Vidsrc chains multiple HTTP fetches inside Rust; Videasy runs AES decrypt via FFI. Player loading overlay and provider switch freeze until Rust returns.

## Root cause

```dart
// vidsrc_extractor.dart
RustLib.instance.resolveVidsrcEmbedJson(req)

// videasy_extractor.dart
RustLib.instance.opensslAesDecryptJson(intermediate, passphrase: '')
```

## Impact

- "Direct Streaming Mode" and provider race UX degrades when vidsrc/videasy are in the provider order
- Cancel button on loading overlay may not respond
- User perceives Rust crash; it is UI isolate starvation

## Solution (2026-07-06)

1. Added typed wrappers in `packages/rust/lib/src/isolate_runner.dart`:
   - `runResolveVidsrcEmbedJson(requestJson)` — multi-page HTTP resolve in Rust
   - `runOpensslAesDecryptJson(intermediate, {passphrase})` — AES decrypt in Rust
2. Updated call sites:
   - `packages/api/lib/playback/vidsrc_extractor.dart` → `await runResolveVidsrcEmbedJson(req).timeout(timeout)`
   - `packages/api/lib/playback/videasy_extractor.dart` → `await runOpensslAesDecryptJson(...)`

Player loading overlay and provider switch stay responsive while Rust resolves.

### Not done (follow-up)

- Cancellation token plumbed into Rust resolver

## Acceptance

- [x] Both extractors use `runRustIsolate` for FFI entry points
- [ ] Manual test: vidsrc-first provider order on slow network — UI responsive
- [ ] [004](004-[open]-sync-ffi-ui-thread-audit.md) inventory rows marked fixed
