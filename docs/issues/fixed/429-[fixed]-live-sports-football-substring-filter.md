# 429 — Live Sports sport chip substring-matches related sports

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Live Sports · sport category bar · schedule filter  
**Reported:** 2026-10-14

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I429-T01 | Pack `liveFeedSportMatches`: exact slug match (`football` ≠ `american-football`) | ✅ |
| 2 | I429-T02 | Sync hub `_prelude.js` + bump `forjahq-live-sports` | ✅ |
| 3 | I429-T03 | Host paint kind filter: `liveSportIdsMatch` instead of `contains` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I429-A01 | Manual: Football chip shows soccer only — not NFL / AFL / Australian Football cards | ⬜ |

---

## Summary

**Symptom:** Picking **Football** (soccer) also listed American Football, Australian Football, and NFL rows whose category string contains `football`.

**Root cause:** Hub `liveFeedSportMatches` used `kind.indexOf(want) >= 0`. Host paint `_itemMatchesKindFilter` used `kind.contains(needle)` on reload flash of the previous page.

**Fix:** Exact slug-normalized equality in the pack filter (and host paint), same idea as `liveSportIdsMatch`.
