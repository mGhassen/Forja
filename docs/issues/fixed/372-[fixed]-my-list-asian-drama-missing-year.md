# 372 — My List Asian Drama cards missing year

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** My List · Asian Drama · card subtitle  
**Reported:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I372-T01 | My List: enrich missing year before paint; keep Simkl year when local drama wins | ✅ |
| 2 | I372-T02 | Prefer DRAMA label over `tmdbMediaType: tv` on hub drama rows | ✅ |
| 3 | I372-T03 | Asian Drama: fill `releaseInfo` from TMDB / title / episode air date | ✅ |
| 4 | I372-T04 | Host bookmark save uses premiereDate when releaseInfo empty | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I372-A01 | Plan to Watch Asian Drama cards show `YYYY • DRAMA` when year is known | ✅ |
| 2 | I372-A02 | Drama bookmarks with TMDB id fill year on My List refresh without re-add | ✅ |

---

## Cause

Asian Drama bookmarks often store empty `releaseDate` (KissKH omits it; year may only be in the title or on TMDB). My List painted `DRAMA` from kind alone and never ran TMDB enrich for missing year. When a local drama row replaced a Simkl stub, Simkl’s year was dropped. Rows with `tmdbMediaType: tv` also showed **TV** instead of **DRAMA**.

---

## Related

- [My List feature guide](../features/movies-tv/my-list.md)
- [371](fixed/371-[fixed]-my-list-open-with-regression.md)
