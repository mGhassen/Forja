# 435 — Live Sports re-scrapes every catalog when switching tabs back

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · progressive schedule · feed cache

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I435-T01 | Default `_refreshForceNetwork` false (true wiped cache on first chrome epoch bump) | ✅ |
| 2 | I435-T02 | Restore `_warmLiveScheduleReuse` so soft chrome bumps keep the painted schedule | ✅ |
| 3 | I435-T03 | Strip `force` / `forceRefresh` from progressive reduce params (pack must not clear `live_sports.feed`) | ✅ |
| 4 | I435-T04 | `PackChromeScope.refreshForceNetwork` default false to match painter | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I435-A01 | Load Live Sports fully → leave hub → return: no `Loading … 1/N` scrape; schedule stays painted | ⬜ |

---

## Summary

Switching away from Live Sports and back re-ran the full progressive catalog fan-out (`Loading bzhsport… 1/N`) even after a warm load. Regression from [41137cd37](https://github.com/mGhassen/Forja/commit/41137cd375f8105e0acc56c77331aaf9bc14f99b): `_refreshForceNetwork` defaulted to **true**, `_warmLiveScheduleReuse` was removed, and reduce-step params kept `force` so the pack cleared `live_sports.feed` while shaping rows.

**Root fix:** restore false-until-Refresh force-network default, warm schedule reuse on soft chrome bumps, and strip force from progressive reduce params. User **Refresh** / pack wipe still force-network.

**Related:** [314](314-[fixed]-live-sports-settings-wipes-feed-cache.md) · [375](375-[fixed]-hub-keep-alive-keeps-fetching-off-tab.md) · feature [live-sports](../../features/live/live-sports.md)
