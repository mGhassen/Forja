# 520 — Simkl movie list status wiped by history/remove after add

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Simkl · My List · films · list status  
**Reported:** 2026-10-31 (Plan to Watch / other statuses local OK; Simkl delete works; Simkl add does not stick)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. Remove from My List → Simkl library row gone (correct).
2. Set Plan to Watch (or Watching / On Hold / Dropped) on a **film** → local My List updates; Simkl never keeps the row (or it flashes then vanishes).
3. TV / anime list writes were less affected (no post-add history remove on shows).

## Root cause

`SimklService.setListStatus` after a successful movie `/sync/add-to-list` called `/sync/history/remove` for every non-`completed` status. Title-level history/remove **deletes the whole library entry** (same path as intentional remove-from-watchlist) — so plantowatch/watching/hold/dropped were added then immediately wiped.

Verified: `setListStatus` movies branch; `removeFromWatchlist` docs already note history/remove clears plantowatch films.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I520-T01 | After movie add-to-list, only `/sync/history` when stored status is `completed` — never history/remove | ✅ |
| 2 | I520-T02 | Unit test for history-mirror policy | ✅ |
| 3 | I520-T03 | Changelog + issue close | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I520-A01 | Film → Plan to Watch stays on Simkl library | ⬜ |
| 2 | I520-A02 | Film → Completed still marks watched history; remove still clears Simkl | ⬜ |

## Links

- Follow-on to film path in [500](500-[fixed]-simkl-list-status-rewrite-and-mediatype.md) (mediaType / rewrite; this wipe remained)
- [Simkl history/remove](https://api.simkl.org/) — title-level remove = full library delete
