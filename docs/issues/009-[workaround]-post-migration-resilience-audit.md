# 009 — Post-migration resilience audit (broken network / cancel / UX)

**Priority:** P2  
**Severity:** Medium  
**Status:** workaround (2026-07-06) — host cancel UX shipped; root abort open in [015](015-[open]-rust-blocking-http-engine-debt.md)  
**Area:** `apps/forja`, `packages/api`  
**Reported:** 2026-07-06

## Summary

Wave 1 migration verified **functional parity** (Rust goldens, happy-path smoke). It did **not** systematically test behavior under failure: dead networks, timeouts, empty scrapes, mid-flight cancel.

**Two layers** (see [honesty rule](../../.cursor/rules/honesty-and-completion.mdc)):

| Layer | What we shipped | What remains |
|-------|-----------------|--------------|
| **Symptom / UX** | Gen-token cancel, Stop buttons, discard stale results — UI stays responsive | Manual QA per flow below |
| **Root / engine** | Not in scope here | [015](015-[open]-rust-blocking-http-engine-debt.md) — Rust still blocks internally; cancel does not abort in-flight HTTP |

Do **not** mark FFI-related rows `[fixed]` — those are `[workaround]` in [001](001-[workaround]-webstreamr-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md), [011](011-[workaround]-kisskh-hls-sync-ffi.md).

## Host cancel work (symptom layer — shipped)

- **Details** (`details_screen.dart`): gen-token for torrent / Stremio / Nuvio; Cancel in results header.
- **Streaming** (`streaming_details_screen.dart`): Cancel discards WebStreamr / Vidsrc / Nuvio / Videasy / headless WebView results.
- **Player** (mobile + desktop): `_fallbackGen` aborts auto-fallback and manual `_switchProvider` on exit; `cancelPending()` on dispose.
- **IPTV scrape**: Stop + bounded empty-page exit — [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) **fixed** (logic bug, not FFI).
- **IPTV channel scan**: Stop + `isCancelled` through verify / portal fetch.

**Limitation (honest):** Cancel = discard results + stop applying UI updates. Worker isolate / Rust / headless WebView may still run until timeout. Root abort: [015](015-[open]-rust-blocking-http-engine-debt.md).

## Audit checklist

Code reviewed 2026-07-06. **Manual device QA not run** — rows marked "needs QA" where behavior is implemented but unverified on device.

| Flow | Spinner | Back works | Error message | No infinite loop | Cancel / escape | Status |
|------|---------|------------|---------------|------------------|-----------------|--------|
| WebStreamr resolve | overlay | yes | yes (empty) | yes | partial — gen discard | workaround [001](001-[workaround]-webstreamr-blocks-ui.md); Rust keeps running |
| IPTV scrape | yes | yes | yes | yes — 4 empty pages | Stop | **fixed** [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) |
| IPTV channel scan | yes | yes | yes | bounded portals | Stop | symptom done; needs QA |
| Stremio browse (details) | yes | yes | yes | yes | Cancel | workaround [005](005-[workaround]-stremio-http-blocks-ui.md) |
| Torrent search (details) | yes | yes | yes | yes | Cancel | workaround [007](007-[workaround]-torrent-search-blocks-ui.md) |
| Vidsrc resolve (streaming) | overlay | yes | yes | timeout 30s | Cancel overlay | workaround [006](006-[workaround]-vidsrc-videasy-extractors-blocks-ui.md) |
| M3U fetch | yes | yes | yes | timeout | none | workaround [011](011-[workaround]-kisskh-hls-sync-ffi.md) |
| Provider race (streaming) | overlay | yes | snackbar | order loop | Cancel | symptom done; needs QA |
| Player auto-fallback | inline | back pops | error UI | provider list finite | exit aborts | symptom done; needs QA |
| Player manual switch | snackbar | back pops | snackbar | — | exit aborts | symptom done; needs QA |
| WebView embed extract | headless | — | null | 60s timeout | overlay dispose | partial — [010](010-[open]-webview-js-extractors-main-thread.md) open |
| Nuvio scraper | overlay / details | yes | yes | JS timeout 30s | gen discard | symptom done; needs QA |

## Deliverables

1. Checklist per flow — **table above** (manual QA still open on most rows)
2. Automated widget/integration tests — **not started**
3. Standard pattern: gen-token + Stop/Cancel — **shipped** for listed flows

## Acceptance

- [x] Host cancel pattern documented (symptom layer vs [015](015-[open]-rust-blocking-http-engine-debt.md))
- [x] Details / streaming / player / IPTV escape hatches in code
- [ ] Manual QA pass on checklist rows marked "needs QA"
- [ ] Widget/integration tests with mocked slow FFI
- [ ] Root cancel-abort in Rust (tracked in [015](015-[open]-rust-blocking-http-engine-debt.md), not this issue)

**Close 009:** workaround shipped. Remaining: manual QA + widget tests (optional); engine cancel → [015](015-[open]-rust-blocking-http-engine-debt.md).
