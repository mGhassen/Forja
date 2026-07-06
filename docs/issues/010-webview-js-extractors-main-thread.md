# 010 — WebView / JS / WASM extractors can block the main thread

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** `apps/forja` (WebView extractors, Nuvio `flutter_js`, Videasy WASM host)  
**Reported:** 2026-07-06

## Summary

Not all "stuck app" reports are Rust FFI. Host-side extractors (C3–C5 per [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)) run on the main isolate by design:

- WebView embed sniff / `stream_extractor`
- Nuvio `flutter_js`
- Videasy WASM (Dart host; Rust decrypt is [006](006-vidsrc-videasy-extractors-blocks-ui.md))

Heavy JS evaluation, WebView navigation chains, and WASM crypto on the UI thread produce the **same frozen-spinner symptom** as sync FFI.

## Impact

- Kisskh / embed providers freeze UI during extraction
- Harder to distinguish from Rust FFI bugs in user reports

## Fix options

- Profile each extractor path; document max expected duration
- Offload WASM decrypt to isolate ([006](006-vidsrc-videasy-extractors-blocks-ui.md))
- WebView: timeout + cancel; avoid synchronous `evaluateJavascript` chains where possible
- Long-term: move scrape chains to Rust where Pattern B applies

## Acceptance

- [ ] Inventory of WebView/JS extractor call sites with estimated block time
- [ ] Timeout + cancel on top 3 slowest paths
- [ ] Documented in ENGINE_BOUNDARY which extractors remain host-only
