# 065 — Source fetch continues after leaving a title

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/nuvio/` · `features/media/details/` · `shared/playback/` · KissKh · player Sources panel  
**Reported:** 2026-07-16

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** fix · **0 / 4** acceptance (manual smoke ⬜) |

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
| 6 | I65-T06 | Gate `NuvioFetchStart` on `_acceptingFetches` so orphaned JS cannot restart HTTP after abort/timeout | ✅ |
| 7 | I65-T07 | Player Sources `dismiss()` cancels Nuvio/Engine before Overlay unmount | ✅ |
| 8 | I65-T08 | One shared cancel (`DomainStreamProviderResolver.cancelAllPending`) for panel switch/close/leave — no UI Nuvio-only calls | ✅ |
| 9 | I65-T09 | Leave title / tab switch sets webstreaming + stream cancel flags (not only Cancel button) so Auto host loop stops after current sniff dies | ✅ |
| 10 | I65-T10 | Anime Cancel uses `_haltBackgroundResolve` (same as dispose); Asian Drama leave/Cancel uses shared `cancelAllPending` + local KissKh cancel | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I65-A01 | Open Sources (Nuvio/Xpass scraping) → leave details → console stops Xpass fetches | ⬜ |
| 2 | I65-A02 | Quit Asian Drama / player mid KissKh extract → WebView extract stops | ⬜ |
| 3 | I65-A03 | Player Sources on All (Nuvio scraping) → close panel → no further `[Nuvio:log] [Xpass] Fetching` lines | ⬜ |
| 4 | I65-A04 | Play episode (webstreaming Auto loading) → switch shell tab (e.g. IPTV) mid-sniff → no further `[vidnest]`/`[vidfast]`/`[2embed]` sniffer lines | ⬜ |

---

## Summary

Leaving a stream or details title left Nuvio scrapers (e.g. Xpass) and KissKh extract running in the background after navigating to another tab. Root causes: details `dispose` only cancelled the Dart subscription (scrapers kept HTTP), `streamAll` never passed cancel into the JS runtime, and `cancelAllPending` did not abort the active KissKh WebView.

**Follow-up (2026-07-16):** Closing the **player** Sources panel still left Xpass/HindMovie logs going. `abortPendingWork` bumped fetch generation so in-flight HTTP died, but orphaned QuickJS Promise chains called `NuvioFetchStart` again with the **new** generation and kept loading. Player `dismiss()` also waited for Overlay dispose (next frame) before cancel. Fixed by refusing new fetches when not accepting work, and cancelling immediately in `PlayerSourcesPanel.dismiss()`.

**Follow-up (unify cancel):** UI no longer special-cases Nuvio. Details panel Cancel / leave, player Sources dismiss, and provider switches all call `DomainStreamProviderResolver.cancelAllPending({cancelEngineJobs})`, which routes through `PlaybackEngine` → `HostProviderAdapter` (webstreaming hosts + Nuvio + KissKh + optional Engine). Miruro is cancelled on the domain resolver. Same product rule as webstreaming: switch load or close panel → stop the old load.

**Follow-up (2026-07-17):** Switching shell tabs mid webstreaming Auto (loading overlay) still walked every host (`[vidnest]` → `[vidfast]` → …). Leave called `cancelAllPending` (kills current WebView) but never set `_webstreamingOnlyExtractionCancelled` / `_streamCancelled` — only the Cancel button did — so `PlaybackEngine` kept the next provider. Fixed: dispose + cancel-with-engine flip those flags; `isCancelled` also honors `!mounted`. Anime Cancel now calls the same `_haltBackgroundResolve` as dispose; Asian Drama leave/Cancel uses shared `cancelAllPending` plus the local KissKh extractor cancel.

**Symptom fix:** abort on leave + honor cancel in `streamAll` + refuse post-abort FetchStart + halt Auto host loop on leave.  
**Root fix:** same — generation-checked scrapers + HTTP client recreate + fetch gate + eager panel dismiss cancel + one shared cancel entry point + leave sets Play cancel flags.
