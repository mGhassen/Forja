# 013 — 111477 captcha / Cloudflare handling still in Dart

**Priority:** P3  
**Severity:** Low  
**Status:** fixed (2026-07-06) — documented split; index scrape accepted as legacy Dart  
**Area:** `packages/api/lib/api/site111477_service.dart`, `crates/proxy/src/seek111477.rs`  
**Reported:** 2026-07-06  
**Tracked:** P2-92 known gap (closed)

## Summary

Loopback proxy consolidated in Rust (P2-92 ✅). Index scrape + Cloudflare/rate-limit retry (HTTP 429, error 1015, 7.2s backoff) remains in `site111477_service.dart` **by decision** — not an oversight.

There is no `crates/site111477` crate. Proxy = `crates/proxy/seek111477`; scrape = legacy `packages/api`.

## Fix (shipped — 2026-07-06)

Accepted **permanent host/legacy-api responsibility** (not a Rust port):

1. **[crates/proxy/README.md](../../crates/proxy/README.md)** — Dart vs Rust table, FFI surface, future port notes.
2. **[ENGINE_BOUNDARY R9](../../docs/ENGINE_BOUNDARY.md#r9--111477-index-scrape-stays-in-dart-legacy-api)** — locked split: scrape in Dart, seek proxy in engine.

No code move — documentation + boundary decision closes the split-brain maintenance question.

## What stays where

| Layer | File |
|-------|------|
| CF / rate-limit on index GET | `site111477_service.dart` `_fetchHtml` |
| Seekable localhost proxy | `crates/proxy/src/seek111477.rs` |
| FFI start/stop | `site111477_proxy.dart` |

## Acceptance

- [x] Document current Dart vs Rust split in crate README (`crates/proxy/README.md`)
- [x] Explicit permanent host/legacy responsibility in ENGINE_BOUNDARY (R9)
