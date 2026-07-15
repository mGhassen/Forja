# 065 — Source fetch continues after leaving a title

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/nuvio/` · `features/media/details/` · `shared/playback/` · KissKh  
**Reported:** 2026-07-16  
**Fixed:** 2026-07-16

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **0 / 2** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I65-T01 | Nuvio `streamAll` / `_runOne` honor `cancelPending` generation + `isCancelled` | ✅ |
| 2 | I65-T02 | `NuvioRuntime.abortPendingWork` closes HTTP + timers on cancel | ✅ |
| 3 | I65-T03 | Details `dispose` aborts Nuvio / Stremio / torrent / domain resolves | ✅ |
| 4 | I65-T04 | `KissKhExtractor.cancelAllPending` wired into player quit cancel path | ✅ |
| 5 | I65-T05 | Details Cancel also calls `Engine.cancelPendingResolve` for torrent/Stremio | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I65-A01 | Open Sources (Nuvio/Xpass scraping) → leave details → console stops Xpass fetches | ⬜ |
| 2 | I65-A02 | Quit Asian Drama / player mid KissKh extract → WebView extract stops | ⬜ |

---

## Summary

Leaving a stream or details title left Nuvio scrapers (e.g. Xpass) and KissKh extract running in the background after navigating to another tab. Root causes: details `dispose` only cancelled the Dart subscription (scrapers kept HTTP), `streamAll` never passed cancel into the JS runtime, and `cancelAllPending` did not abort the active KissKh WebView.

**Symptom fix:** abort on leave + honor cancel in `streamAll`.  
**Root fix:** same — generation-checked scrapers + HTTP client recreate + shared KissKh cancel registry.
