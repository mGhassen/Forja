# Issue 045 — KissKh extract flaky: cache + page-load wait + cancel races

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `asian_drama/catalog/kisskh_extractor.dart`, `shared/player/player/utils.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 5** fix · **0 / 1** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I45-T01 | Disable WebView HTTP cache / incognito for KissKh extract (stale kkey / skipped Episode API) | ✅ |
| 2 | I45-T02 | Stop blocking on `onLoadStop` — wait only for Episode stream API | ✅ |
| 3 | I45-T03 | Serialize resolves + cancel without unhandled `completeError` | ✅ |
| 4 | I45-T04 | Force `Referer: https://kisskh.co/` for KissKh CDN when cache drops headers | ✅ |
| 5 | I45-T05 | Soft-reload + play nudge if Episode API silent | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I45-A01 | Backrooms (and a TVSeries title) resolve to `xhr hit` without stuck “Waiting for stream key…” on cold open | ⬜ |

---

## Summary

KissKh stream extract opened a **cached** headless WebView, waited up to **35s on page load** before treating the Episode API as primary, and overlapping `resolve`/`cancel` calls raced a single extractor (unhandled `TimeoutException: KissKh extraction cancelled`). Playback header fallback also derived `Referer` from the CDN host (`cdnvideo*.shop`) when cached `StreamSource.headers` were missing — CDNs reject that.

**Symptom:** Loading overlay stuck on “Opening kisskh…” / “Waiting for stream key…”; logs show `page load timeout` and silent Episode API.

**Root:** Extractor lifecycle + WebView cache + wrong CDN Referer fallback — not kisskh.co being down.
