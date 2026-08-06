# RFC-053 — Asian Drama TMDB details enrichment

**Status:** partial  
**Depends on:** —  
**Area:** Asian Drama / details

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **5 / 6** acceptance (details enrich) · **3 / 4** acceptance (hero images / stills) |
| **Current slice** | Random TMDB hero backdrops + episode stills (no Images row) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | R53-C01 | Shared KissKH → TMDB title match (`KissKhTmdbMatch`) reused by hub synopsis + details | ✅ |
| 2 | R53-C02 | `asianDramaTmdbEnrichmentProvider` → `getRichDetails` after match | ✅ |
| 3 | R53-C03 | Details UI: genres / rating / facts + Cast / Crew / Trailers / More Like This | ✅ |
| 4 | R53-C04 | Details hero rotates TMDB backdrops; KissKH episode rail merges season-1 stills/meta | ✅ |

---

## Acceptance (details enrich slice)

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | R53-A01 | Details loads KissKH episodes as today; TMDB enrich is best-effort and never blocks playback | ✅ |
| 2 | R53-A02 | Confident TMDB match shows Cast + Trailers + More Like This (when TMDB returns data) | ✅ |
| 3 | R53-A03 | Hero gains genres / rating / network·creator·language facts when TMDB matches | ✅ |
| 4 | R53-A04 | Hub hero synopsis enrich uses the same matcher (overview only) | ✅ |
| 5 | R53-A05 | More Like This opens Home/Search-style TMDB details (`AppRouter.openDetails`) | ✅ |
| 6 | R53-A06 | Device smoke: open a known K-drama details → cast row visible when TMDB match succeeds | ⬜ |

---

## Acceptance (images / stills slice)

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | R53-A07 | Title normalizer strips KissKH year/HD/pipe noise so more titles match TMDB | ✅ |
| 2 | R53-A08 | Confident TV match paints TMDB episode stills (and name/overview when present) on the KissKH episode rail | ✅ |
| 3 | R53-A09 | Confident match rotates TMDB backdrops in the details hero (no separate Images row) | ✅ |
| 4 | R53-A10 | Device smoke: matched title shows rotating hero art and/or episode thumbnails | ⬜ |

---

## Summary

KissKH details only ship synopsis + episode list. Anime and Home details already show cast / trailers / recommendations. Asian Drama should match the KissKH title on TMDB and reuse the shared media-details sections.

## Problem

1. **Thin details** — `AsianDramaDetailsScreen` is hero + episode rail only.
2. **KissKH has no cast** — `/DramaList/Drama/{id}` has no characters / crew / trailers.
3. **Hub already matches TMDB** for empty hero synopsis but discards the TMDB id.

## Goals

- Persist KissKH → TMDB match (id + mediaType) for details enrichment.
- Drop in `MediaDetailsCastSection` / trailers / recommendations like anime/movies.
- Keep KissKH as the playback source of truth; TMDB is metadata-only.
- Fail soft — no match ⇒ details look as today.

## Contracts

- Match scoring: title similarity + year proximity + TV-vs-movie preference from KissKH `type`.
- Min score threshold unchanged from hub trial (`≥ 2`).
- Recommendations leave the KissKH hub and open TMDB `DetailsScreen` (stream providers available there).
- No AniList — Asian dramas are real-actor cast, not anime characters.

## Related

- [Asian Drama feature guide](../features/hubs/asian-drama.md)
- Anime details cast/recs pattern (`anime_details_screen.dart`)
- Hub synopsis trial (`asian_drama_screen.dart`)
