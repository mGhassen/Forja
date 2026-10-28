# 438 — Anime details episode list truncated / misnumbered

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** anime · details · AniList `streamingEpisodes` · TMDB enrich  
**Related:** [100](../100-[open]-anime-details-cast-recs-trailers.md) · [210](../210-[open]-episode-watched-list-simkl-follow.md) · [353](353-[fixed]-iptv-series-details-missing-episodes.md) · [513](513-[fixed]-anime-season1-franchise-stream-titles.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I438-T01 | Parse real episode numbers from AniList `streamingEpisodes` titles (not array index) | ✅ |
| 2 | I438-T02 | Pad `meta.videos` to AniList `episodes` / `nextAiringEpisode` (full 1..N) | ✅ |
| 3 | I438-T03 | TMDB enrich pads sparse videos to `facts.episodeCount` when larger | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I438-A01 | One Piece details: episode list length matches declared total (~1180+), E130 is episode 130 | ⬜ |
| 2 | I438-A02 | Short finished series (e.g. 12 eps) still lists 1..12 with correct titles | ⬜ |

---

## Summary

Anime details facts showed TMDB `number_of_episodes` (e.g. One Piece **1180**), while the picker only had AniList’s recent `streamingEpisodes` window (**69** rows), numbered `i+1` so **E1** showed title **Episode 130**.

**Root:** `anilistVideosFromMedia` treated `streamingEpisodes.length` as the full list and used array index as `episode`. AniList leaves `episodes` null on long-running titles; the real ceiling is `nextAiringEpisode.episode` (e.g. 1181).

**Fix (forja-packs `forjahq-anime` 1.0.51):** parse episode numbers from titles; pad to declared / next-airing total; enrich also pads to TMDB `facts.episodeCount` when the AniList list is still short.
