# 006 — Vidsrc / Videasy extractors block the UI thread

**Priority:** P1  
**Severity:** High  
**Status:** open  
**Area:** `packages/api/lib/playback/vidsrc_extractor.dart`, `videasy_extractor.dart`, `crates/stream-core`  
**Reported:** 2026-07-06  
**Parent:** [004](004-sync-ffi-ui-thread-audit.md)

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

## Fix

- `runResolveVidsrcEmbedJson` / `runOpensslAesDecryptJson` in `isolate_runner.dart`
- Wire extractors through wrappers
- Optional: cancellation token plumbed into Rust resolver

## Acceptance

- [ ] Both extractors use `runRustIsolate` for FFI entry points
- [ ] Manual test: vidsrc-first provider order on slow network — UI responsive
- [ ] [004](004-sync-ffi-ui-thread-audit.md) inventory rows marked fixed
