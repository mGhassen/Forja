# 513 — Anime Season 1 shows franchise-absolute stream titles (Slime E49+)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** anime · details · AniList `streamingEpisodes`  
**Reported:** 2026-10-28 (device screenshot — Slime Season 1 → E1 “Episode 49 - Demons and Strategies”)  
**Related:** [098](../098-[open]-anime-details-season-chain.md) · [438](438-[fixed]-anime-details-streaming-episodes-truncated.md) · [514](514-[fixed]-anime-tmdb-enrich-wrong-season-stills.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Multi-cour anime (That Time I Got Reincarnated as a Slime) on **Season 1** listed E1… with titles **Episode 49+** (Season 3 absolute titles). Air dates stayed Season 1.

## Root cause

AniList returns the **same franchise-recent** `streamingEpisodes` window (e.g. Episode 49…72) on every Media in the chain, including Season 1. Pack `anilistVideosFromMedia` (I98-T15) remapped that window with `offset = maxParsed - Media.episodes`, gluing the trailing absolute rows onto relative 1..N.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I513-T01 | Keep only `streamingEpisodes` whose parsed abs ≤ `Media.episodes`; drop last-N offset | ✅ |
| 2 | I513-T02 | Treat `Episode N - …` as generic so TMDB enrich replaces leftover absolute titles | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I513-A01 | Slime Season 1: E1…E24 are Season 1 titles (not Episode 49+) after pack refresh | ✅ (simulated AniList 101280 → generic Episode 1..24; TMDB enrich fills names) |
| 2 | I513-A02 | Manual QA on device after soft-pull `forjahq-anime` 1.0.64+ | ⬜ |

## Links

- Pack: `forjahq-anime` **1.0.64** (`anilist.js` / `_kit.js`)
