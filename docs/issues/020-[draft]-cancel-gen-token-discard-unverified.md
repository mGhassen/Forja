# 020 — Gen-token cancel may discard valid results (unverified)

**Priority:** P2  
**Severity:** Medium  
**Status:** draft  
**Parent:** [018](018-[draft]-migration-playback-parity-unverified.md)  
**Area:** `apps/forja/lib/features/home/details_screen.dart`, `streaming_details_screen.dart`, `packages/api/lib/playback/providers/services/webstreamr_service.dart`, player screens  
**Reported:** 2026-07-07  
**Related:** [009](fixed/009-[fixed]-post-migration-resilience-audit.md) (cancel UX shipped; races not QA’d)
## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** acceptance |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---


## Summary

Cancel/resilience work uses **generation tokens** to discard stale async results. This is correct when the user taps Cancel or navigates away. It can **look like “lost list”** if the generation increments at the wrong time — valid results arrive but are thrown away because `gen != _resolveGeneration`.

Shipped in:

| Location | Mechanism |
|----------|-----------|
| `WebStreamrService` | `_resolveGeneration` + `cancelPending()` |
| `details_screen.dart` | `_torrentSearchGen`, `_stremioFetchGen`, Nuvio cancel |
| `streaming_details_screen.dart` | `_extractionCancelled`, provider cancel |
| Player (mobile/desktop) | `_fallbackGen`, `cancelPending()` on dispose |

**None of these race paths have been manually verified** per [009](fixed/009-[fixed]-post-migration-resilience-audit.md) (“needs QA” rows).

## Scenarios to verify

| # | Action | Expected | Failure mode |
|---|--------|----------|--------------|
| 1 | WebStreamr resolve completes; user did **not** cancel | Full source list in player | Empty list / single URL only |
| 2 | Cancel mid-resolve → tap Play again | Second resolve succeeds | Permanent empty until app restart |
| 3 | Back from details during torrent search | No stale results applied on return | Wrong torrent list flashes |
| 4 | Switch Stremio addon while previous fetch in flight | Only latest addon streams shown | Mixed or empty list |
| 5 | Exit player during auto-fallback | No crash; next play clean | Hang or empty sources |
| 6 | IPTV channel scan Stop → restart | Fresh results | Stale channels |

## Root cause (if bug found)

Likely double-increment of generation on navigation + explicit cancel, or `cancelPending()` called on dispose when a new screen already started the next resolve.


## Related

- [017](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md) — UI hid sources (`length > 1`); separate from gen-token
- [016](fixed/016-[fixed]-async-job-ffi-hard-cancel.md) — Rust HTTP abort on cancel
