# 183 — Nuvio empty / thin streams on Android (QuickJS parallel)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Nuvio · Sources · Android TV / QuickJS

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I183-T01 | Serialize `loadScraper` / `getStreams` on one JS mutex | ✅ |
| 2 | I183-T02 | Keep scraper source; reload after abort drops the VM | ✅ |
| 3 | I183-T03 | `abortPendingWork` disposes poisoned QuickJS heap when work was active | ✅ |
| 4 | I183-T04 | Unit: `NuvioJsMutex` serializes overlapping runs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I183-A01 | Unit: mutex starts/finishes jobs in queue order | ✅ |
| 2 | I183-A02 | Unit: mutex unlocks after thrown action | ✅ |
| 3 | I183-A03 | Manual: ATV Sources → Nuvio All on a title that fills desktop — list is no longer empty / thin vs Mac | ⬜ |

---

## Summary

Sources → Nuvio ran up to **5 scrapers in parallel** (`Future.wait` + `kNuvioScraperBatchSize`) against a **single** `flutter_js` runtime. macOS uses JavaScriptCore; Android uses QuickJS. Overlapping `getStreams` + `fetch` + timers on one QuickJS event loop timed out or returned `[]`, so Android TV showed fewer or no streams for the same title/scrapers that worked on desktop.

Upstream NuvioMobile creates a **fresh `JsRuntime` per scraper call**. Forja keeps one warmed runtime (cheerio stays loaded) but **serializes** all JS load/invoke work and **drops the VM on abort** so cancel/timeout cannot leave a poisoned heap for the next scraper.

**Related:** [178](../178-[open]-nuvio-empty-first-scraper-hides-streams.md) · [features/scrapers/nuvio.md](../../features/scrapers/nuvio.md)
