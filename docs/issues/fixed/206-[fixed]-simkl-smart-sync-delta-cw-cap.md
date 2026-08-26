# 206 — Simkl smart sync: full library rewrite + CW flood

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Simkl · watch history · Home continue watching

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0 / 3** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I206-T01 | `date_from` delta after first sync; keep activities gate | ✅ |
| 2 | I206-T02 | Cap continue-watching resume seed (~20 newest missing); skip TMDB when Simkl poster/runtime present | ✅ |
| 3 | I206-T03 | Throttle background `fullSync` (~15 min) across cold starts | ✅ |
| 4 | I206-T04 | Feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I206-A01 | Unchanged Simkl `activities.all` → no library / TMDB flood in logs | ⬜ |
| 2 | I206-A02 | Stamp change → `date_from` pull; CW gains at most ~20 new synthetic resumes | ⬜ |
| 3 | I206-A03 | Reopen within 15 min after sync → skip without re-pull | ⬜ |

---

## Summary

Background `SimklService.fullSync` gated on `activities.all`, but when the stamp moved it re-fetched entire watching/completed lists (no `date_from`), then wrote up to 100+ synthetic 5% resumes into a 50-slot watch-history bag with one TMDB GET each.

**Fix:** first sync / Sync Now still full-pulls; continuous sync uses `date_from`; CW resumes newest-first capped at 20; Simkl poster/runtime preferred over TMDB; 15‑minute throttle on background `fullSync`; logout clears activity + throttle stamps.

## Related

- [Simkl](../features/accounts/simkl.md)
- [Watch history](../features/movies-tv/watch-history.md)
