# 006 — Vidsrc / Videasy extractors block the UI thread

**Priority:** P1  
**Severity:** High  
**Status:** workaround (2026-07-06) — UI no longer freezes; root cause open  
**Root fix:** [015](015-[fixed]-rust-blocking-http-engine-debt.md)  
**Area:** `packages/api/lib/playback/vidsrc_extractor.dart`, `videasy_extractor.dart`, `crates/stream-core`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[fixed]-sync-ffi-ui-thread-audit.md)

## Status summary

| Layer | Status | Notes |
|-------|--------|-------|
| **Symptom** — UI thread blocks during resolve/decrypt | **workaround** | isolate wrappers |
| **Root** — multi-page resolve in Rust (`webstreamr` vidsrc) | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| **Cancel** — abort in-flight resolve | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |

## Root cause (before fix)

```dart
RustLib.instance.resolveVidsrcEmbedJson(req)      // vidsrc — chained HTTP in Rust
RustLib.instance.opensslAesDecryptJson(...)       // videasy — AES in Rust
```

## Workaround (shipped — 2026-07-06)

Isolate offload — stops UI freeze but **does not fix** multi-page blocking resolve in `crates/stream-core`. Root fix: [015](015-[fixed]-rust-blocking-http-engine-debt.md).

1. `runResolveVidsrcEmbedJson`, `runOpensslAesDecryptJson` in `isolate_runner.dart`.
2. `vidsrc_extractor.dart:54` → `await runResolveVidsrcEmbedJson(req).timeout(timeout)`.
3. `videasy_extractor.dart:169` → `await runOpensslAesDecryptJson(...)`.

**Verify:** no direct `RustLib.instance.resolveVidsrcEmbedJson` / `opensslAesDecryptJson` in `packages/api/lib/playback/`.

## Root fix (open)

Track in [015](015-[fixed]-rust-blocking-http-engine-debt.md): async resolve chain in `crates/stream-core`; cancel token.

## If this file is deleted

Engine debt remains tracked in **[015](015-[fixed]-rust-blocking-http-engine-debt.md)**.

## Acceptance

- [x] Both extractors use `runRustIsolate` for FFI entry points
- [ ] Manual test: vidsrc-first on slow network — UI responsive
