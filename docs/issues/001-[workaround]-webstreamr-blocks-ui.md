# 001 — WebStreamr extraction blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/02-rust-engine-complete.md))  
**Status:** workaround (2026-07-06) — UI no longer freezes; root cause open  
**Root fix:** [015](015-[open]-rust-blocking-http-engine-debt.md)  
**Area:** `packages/api/lib/playback/webstreamr_service.dart`, `packages/rust/lib/src/isolate_runner.dart`, `crates/webstreamr`  
**Reported:** 2026-07-06

## Status summary

| Layer | Status | Notes |
|-------|--------|-------|
| **Symptom** — UI thread blocks during resolve | **workaround** | `runWebstreamrGetStreamsJson` → worker isolate |
| **Root** — blocking HTTP, sequential 21 sources in Rust | **open** | [015](015-[open]-rust-blocking-http-engine-debt.md) |
| **Cancel** — abort in-flight Rust work | **partial** | Generation discard only; Rust keeps running — [009](009-[open]-post-migration-resilience-audit.md) |

## Root cause (before fix)

1. Sync FFI on the main isolate — `RustLib.instance.webstreamrGetStreamsJson()` blocked until Rust returned.
2. Blocking HTTP in Rust — `crates/webstreamr` uses `reqwest::blocking`, 20s timeout per request.
3. Sequential source resolution — all 21 sources queried one after another.

## Workaround (shipped — 2026-07-06)

Isolate offload — stops UI freeze but **does not fix** blocking HTTP or sequential resolve in `crates/webstreamr`. Root fix: [015](015-[open]-rust-blocking-http-engine-debt.md).

1. `runWebstreamrGetStreamsJson` in `packages/rust/lib/src/isolate_runner.dart` — loads Rust dylib in worker isolate.
2. `packages/api/lib/playback/webstreamr_service.dart:50`:

```dart
final raw = await runWebstreamrGetStreamsJson(jsonEncode(request));
```

3. `WebStreamrService.cancelPending()` — generation counter discards stale results when user cancels (UI responsive; Rust may still finish in worker).

**Verify:** `grep runWebstreamrGetStreamsJson packages/api` — no direct `RustLib.instance.webstreamrGetStreamsJson` in production.

## Root fix (open)

Track in [015](015-[open]-rust-blocking-http-engine-debt.md):

- `crates/webstreamr`: async HTTP, parallel source resolve, early exit
- Cancel token into Rust resolver ([009](009-[open]-post-migration-resilience-audit.md))

## If this file is deleted

Engine debt remains tracked in **[015](015-[open]-rust-blocking-http-engine-debt.md)**.

## Related

- [004](004-[open]-sync-ffi-ui-thread-audit.md) — parent audit
- `crates/webstreamr/src/resolver.rs`, `crates/webstreamr/src/fetcher.rs`
