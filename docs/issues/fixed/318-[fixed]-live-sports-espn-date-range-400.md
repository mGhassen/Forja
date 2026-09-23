# 318 — Live Sports ESPN catalog empty (scoreboard date range 400)

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · ESPN catalog  
**Reported:** 2026-09-23

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I318-T01 | ESPN pack: fetch scoreboard per day (no `YYYYMMDD-YYYYMMDD` range) | ✅ |
| 2 | I318-T02 | Bump `forjahq-livesports` pack version | ✅ |
| 3 | I318-T03 | Changelog — ESPN schedule shows week-ahead matches again | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I318-A01 | Manual: Catalog → ESPN with Schedule **Next · 24h** / **24h** shows fixtures (engine `espn … raw=` ≫ 2) | ⬜ |

---

## Summary

**Symptom:** Live Sports **Catalog → ESPN** showed no matches. Engine logged `espn done … raw=2` (near-empty) while other catalogs still worked. Default **Airing** filter can hide scheduled rows; the catalog itself was also nearly empty.

**Root:** Pack used ESPN `dates=START-END` ranges (`daysAhead: 7`). `site.api.espn.com` scoreboard returns **HTTP 400** for that form (single `YYYYMMDD` is required). Failed days became `[]`, so almost no rows survived.

**Fix (root):** `livesports/espn.js` expands the window into daily stamps and fetches each day, then dedupes by event id. Pack version **2.0.14**.

**Note:** Hub default Schedule chip is **Airing**. ESPN rows are mostly scheduled — switch to **Next · 24h** (or similar) to see upcoming fixtures when nothing is in play.
