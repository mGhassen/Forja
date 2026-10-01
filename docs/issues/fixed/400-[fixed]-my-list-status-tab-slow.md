# 400 — My List status tabs reload the whole library

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** My List · status tabs  
**Reported:** 2026-10-01

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I400-T01 | My List feed: TMDB enrich only when poster, title, or year is missing | ✅ |
| 2 | I400-T02 | Simkl watchlist: one parallel library fetch, reused for every status | ✅ |
| 3 | I400-T03 | Keep the composed status feed in memory long enough to switch back | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I400-A01 | Plan to Watch → Watching paints from the saved list without a per-card TMDB details call when poster and year are already known | ✅ |

---

## Cause

Each status tab ran `my-list-hub` `feed` again. That awaited three sequential Simkl `all-items` calls, then TMDB details (with images) for every row whose score was 0 or whose logo was missing. Simkl stubs always set score to 0 and never store a logo, so every card blocked the grid. The feed itself is memory-only and expired after 30 seconds, so the next switch repeated the same work. Bookmarks were already in sqlite the whole time.

---

## Related

- [My List feature guide](../../features/movies-tv/my-list.md)
- [372](372-[fixed]-my-list-asian-drama-missing-year.md)
