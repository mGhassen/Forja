# 216 — Anime hub Torrents search returns nothing

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `plugins/hubs/anime`, `plugins/hubs/asian_drama`, `apps/forja` Sources / torrent search  
**Reported:** 2026-09-02

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6 / 6** fix · **2 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I216-T01 | Anime TMDB enrich attaches `ids.imdb` from TMDB `external_ids` | ✅ |
| 2 | I216-T02 | `catalogMetaToMovie` passes `ids.imdb` onto `Movie.imdbId` | ✅ |
| 3 | I216-T03 | Pack emits `open.torrentEp`; host searches `Title 05` when set | ✅ |
| 4 | I216-T04 | Unit tests for anime vs western torrent query passes | ✅ |
| 5 | I216-T05 | Asian Drama pack sets `open.torrentEp: true` | ✅ |
| 6 | I216-T06 | Asian Drama TMDB enrich attaches `ids.imdb` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I216-A01 | Anime details Sources → Torrents can return Nyaa (and other text) rows for a known title | ⬜ |
| 2 | I216-A02 | When enrich matched TMDB with IMDb, Torrentio runs for hub titles with `torrentEp` | ✅ |
| 3 | I216-A03 | Packs without `open.torrentEp` still search `Title Sxx` / `SxxExx` | ✅ |
| 4 | I216-A04 | Asian Drama details Sources → Torrents can return rows for a known title | ⬜ |

---

## Summary

Anime hub Sources → Torrents used the western TV query shape (`Romaji S01E05`) and never supplied an IMDb id. Nyaa-style releases use episode numbers (`Title 05`); Torrentio needs `tt…`. Result: empty torrent lists on Anime.

## Root cause

1. **No IMDb on anime meta** — enrich only wrote `ids.tmdb`; Torrentio short-circuits without `imdbId`.
2. **`catalogMetaToMovie` dropped IMDb** for hub metas even if `ids.imdb` existed.
3. **Wrong query shape** — Sources always searched `Title S01E0N`; fansub releases rarely use that.

## Fix (shipped)

- Anime enrich fetches / appends TMDB `external_ids` → `ids.imdb`.
- Host maps `ids.imdb` → `Movie.imdbId`.
- Anime pack sets `open.torrentEp: true`; host searches `Title 05` / `Title - 05` when that flag is set (any pack can use it — host does not branch on surface).
- Asian Drama pack (v1.0.9): same `torrentEp` + enrich IMDb.

## Related

- [RFC-054](../rfc/054-[partial]-torrent-search-providers.md) — R54-A12–A15
- [Torrent scrapers](../features/scrapers/torrent.md)
- [Anime](../features/hubs/anime.md)
- [Asian Drama](../features/hubs/asian-drama.md)
