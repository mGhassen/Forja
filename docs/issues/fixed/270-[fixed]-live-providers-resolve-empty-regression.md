# Issue 270: Live Sports Providers empty (resolve regression)

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** live sports / providers resolve

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I270-T01 | Forward `homeTeam` / `awayTeam` / `dateMs` / `fixtureSearch` / `eventId` in flutter_js + EngineJS invokers | ✅ |
| 2 | I270-T02 | Providers discover keeps embed mirrors; playable filter only on unlock-on-play | ✅ |
| 3 | I270-T03 | Pack `ownedSources` + prefer card source token on discover (Streamed goat slots) | ✅ |
| 4 | I270-T04 | Clear stale VOD `url` on live extract; Streamic `streamicReadBody` (no `readFetchBody` shadow) | ✅ |
| 5 | I270-T05 | Engine bump 1.2.72; livesports pack 2.0.5 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I270-A01 | Manual: open a live match → Providers lists mirrors from Streamed/PPV/WatchFooty/… (not empty while catalog has rows) | ⬜ |

---

## Summary

Catalog scrapes succeeded (`raw` hundreds) while every Providers resolve returned `raw=0` / `streams=0`. Soft-match fields never reached pack JS; discover results were stripped to HLS-only; Streamed ownership missed goat `sources[]`; Streamic failed to load on flutter_js (`readFetchBody` shadow).

**Symptom fix:** invoker fields + discover row keep + ownership + Streamic rename.  
**Root fix:** same — host contract restored; pack declares `ownedSources`.
