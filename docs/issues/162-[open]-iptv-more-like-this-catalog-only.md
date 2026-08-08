# 162 — IPTV More like this only playable portal titles

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV · movie/series details · TMDB recommendations

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I162-T01 | `filterIptvCatalogRecommendations` — TMDB ∩ active-portal vod/series (exact cleaned title + year gate) | ✅ |
| 2 | I162-T02 | `IptvController.vodSeriesCatalog` — session/disk Movies+Series (no network) | ✅ |
| 3 | I162-T03 | Movie/series details: filter recs; hide row when empty; tap opens IPTV details (not Home) | ✅ |
| 4 | I162-T04 | Unit tests for matcher (exact / year mismatch / series / exclude / ignore live) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I162-A01 | IPTV movie details: More like this shows only titles present on the active portal Movies/Series shelves; tap opens IPTV details | ⬜ |
| 2 | I162-A02 | When TMDB has recs but none match the portal catalog, the More like this row is hidden (no Home/torrent jump) | ⬜ |

---

## Summary

IPTV movie/series details used raw TMDB recommendations and `AppRouter.openDetails` (Home/torrent). Users expect playable portal titles only.

**Fix:** Intersect TMDB recommendations with the active portal’s cached Movies + Series catalog (cleaned title match). Tap opens `openIptvMovieDetails` / `openIptvSeriesDetails`. Empty intersection hides the row. Live TV and the IPTV player are unchanged.
