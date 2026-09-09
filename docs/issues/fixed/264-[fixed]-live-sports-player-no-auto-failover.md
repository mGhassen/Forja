# 264 — Live Sports player does not auto-play the next stream

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · IPTV player failover · live engine unlock

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I264-T01 | Unlock miss on open/failover skips to next Providers row (toast only when exhausted) | ✅ |
| 2 | I264-T02 | `_openCurrent` treats unlock/open miss as failure (no false “ready” timers) | ✅ |
| 3 | I264-T03 | Multi-source liveEngine/Stremio hops after 2 soft reconnects (not 8) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I264-A01 | Dead first Providers mirror → player shows Switching… and opens the next row without manual Source pick | ⬜ |
| 2 | I264-A02 | Unlock fails on mirror 2 of 5 → skips to 3…; toast **No playable stream** only after the last miss | ⬜ |

---

## Summary

Live Sports handoff already passes every Providers row into the native player (`_orderedLiveEngineSources`). Watchdog recovery rotated after **8** soft reconnects (or immediately on hard TCP/open death). Two gaps broke “try the next one”:

1. **Unlock miss dead-end** — failover advanced to a catalog sibling that still needed GOAT/GASM unlock; `_maybeResolveLiveEngineSource` returned null, toasted **No playable stream**, and `_engineOpenSource` returned without opening or advancing. `_openCurrent` then armed success timers as if play had started.
2. **Slow hop** — soft stalls on a dead CDN burned the full 8-attempt ladder (~30s+) before rotating, so multi-mirror Providers felt like no auto-failover.

**Root fix:** `_engineOpenSource` loops unlock skips across remaining sources (toast only when none left); `_openCurrent` aborts when open returns false; liveEngine/Stremio multi-source uses `_maxRetriesLiveMultiSource` (2) before rotate. Portal single-channel reconnect stays at 8.

**Related:** [Live Sports](../../features/live/live-sports.md) · [no-embed-playback](../../../.cursor/rules/no-embed-playback.mdc)
