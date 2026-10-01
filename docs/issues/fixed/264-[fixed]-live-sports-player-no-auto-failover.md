# 264 — Live Sports player does not auto-play the next stream

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · IPTV player failover · live engine unlock

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6/6** tasks · **0 / 2** acceptance A03–A04 (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I264-T01 | Unlock miss on open/failover skips to next Providers row (toast only when exhausted) | ✅ |
| 2 | I264-T02 | `_openCurrent` treats unlock/open miss as failure (no false “ready” timers) | ✅ |
| 3 | I264-T03 | Multi-source liveEngine/Stremio hops after 2 soft reconnects (not 8) | ✅ |
| 4 | I264-T04 | Live Sports / Stremio: never auto-rotate `_sourceIdx` on dead endpoint or retry ladder | ✅ |
| 5 | I264-T05 | Live Sports / Stremio: unlock miss stays on picked row (toast **No playable stream**) | ✅ |
| 6 | I264-T06 | Remove `_maxRetriesLiveMultiSource` early-hop path | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I264-A01 | Dead first Providers mirror → player shows Switching… and opens the next row without manual Source pick | ⬜ |
| 2 | I264-A02 | Unlock fails on mirror 2 of 5 → skips to 3…; toast **No playable stream** only after the last miss | ⬜ |
| 3 | I264-A03 | Dead / stalling Providers mirror stays on that row (reconnect / cold retry) — no Switching… hop | ⬜ |
| 4 | I264-A04 | Unlock fail on picked row → **No playable stream**; other Providers rows untouched until Source pick | ⬜ |

I264-A01 / A02 describe the inverted interim behavior (T01/T03). Superseded by A03 / A04.

---

## Summary

Live Sports handoff passes every Providers row into the native player (`_orderedLiveEngineSources`). Product rule: **never auto-change streams** — reconnect the picked URL only; **Source** is the only way to change row.

T01–T03 briefly shipped auto-hop (unlock skip + 2-retry rotate). T04–T06 reverse that for `liveEngine` / `stremio` via `_pinLiveProvidersSource`. IPTV portal multi-mirror rotate is unchanged. T02 (open miss ≠ false ready) stays.

**Root fix:** `_pinLiveProvidersSource` gates recovery rotate, dead-endpoint hop, and `_engineOpenSource` unlock skips. Same-URL soft reconnect + cold retry remain.

**Related:** [Live Sports](../../features/live/live-sports.md) · [no-embed-playback](../../../.cursor/rules/no-embed-playback.mdc) · skill [forja-live-native-playback](../../../.cursor/skills/forja-live-native-playback/SKILL.md)
