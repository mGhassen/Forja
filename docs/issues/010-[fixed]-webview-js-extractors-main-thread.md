# 010 — WebView / JS / WASM extractors can block the main thread

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed (2026-07-06) — timeout + cancel on slow paths; inventory in ENGINE_BOUNDARY R8  
**Area:** `apps/forja`, `packages/api` (WebView extractors, Nuvio `flutter_js`, Videasy WASM host)  
**Reported:** 2026-07-06

## Summary

Host-side extractors (C3–C5 per [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)) run on the main Dart isolate by design. Heavy WebView navigation, JS evaluation, and WASM crypto can freeze the spinner — same symptom as sync Rust FFI.

**Fix shipped:** timeout + cancel on the three slowest paths; full inventory documented in [ENGINE_BOUNDARY R8](../ENGINE_BOUNDARY.md#r8--host-side-extractors-c3c5-stay-on-the-ui-isolate).

## What remains (not this issue)

Extractors **stay on the UI isolate** — that is intentional (WebView/WASM cannot move off main thread). Long-term: port scrape chains to Rust where Pattern B applies.

## Inventory — call sites (verified 2026-07-06)

| Path | File | Est. block | Timeout | Cancel |
|------|------|------------|---------|--------|
| Embed sniff (vidlink, vixsrc, …) | `stream_extractor.dart` | 5–60s | ✅ | ✅ `cancel()` |
| Kisskh episode resolve | `kisskh_extractor.dart` | 10–25s | ✅ 25s | ✅ `cancel()` |
| Amri sources | `amri_extractor.dart` | 15–30s | ✅ 30s | ✅ `cancel()` |
| Nuvio scrapers | `nuvio_runtime.dart` | 10–30s | ✅ 30s | ✅ `cancelPending()` |
| Videasy WASM + HTTP | `videasy_extractor.dart` | 5–45s | ✅ 45s | ✅ `isCancelled` |
| Arabic WebView fallback | `arabic_service.dart` | 5–15s | ✅ 15s | via StreamExtractor |
| Visible embed UI | `stream_extractor_view.dart` | user-driven | — | user closes view |
| Comic page extract | `comic_page_extractor.dart` | 5–20s | partial | dispose only |

## Fix (shipped — 2026-07-06)

1. **`StreamExtractor`** — `cancel()`, `isCancelled` param; wired in `streaming_details_screen`, player fallback loops.
2. **`KissKhExtractor`** — `cancel()`, `isCancelled`; dispose cancels in-flight resolve; subtitle decrypt bails on cancel.
3. **`AmriExtractor`** — `cancel()`, `isCancelled`, configurable timeout.
4. **Nuvio / Videasy** — already had timeout + cancel; documented in R8.
5. **ENGINE_BOUNDARY R8** — host extractor inventory + mitigation rules.

**Verify:** Cancel during stream extraction overlay → WebView disposed, no hang until full timeout.

## Acceptance

- [x] Inventory of WebView/JS extractor call sites with estimated block time
- [x] Timeout + cancel on top 3 slowest paths (StreamExtractor, KissKh, Nuvio/Amri)
- [x] Documented in ENGINE_BOUNDARY which extractors remain host-only (R8)
