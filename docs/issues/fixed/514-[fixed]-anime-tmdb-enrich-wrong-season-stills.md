# 514 — Anime TMDB enrich paints Season 1 titles on later season chips

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** anime · details · TMDB enrich · season chain  
**Reported:** 2026-10-28 (Slime Season 4 chip → Season 1 episode names, Season 4 air dates)  
**Related:** [098](../098-[open]-anime-details-season-chain.md) · [513](513-[fixed]-anime-season1-franchise-stream-titles.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Season 4 (and other non-S1 chips) kept correct cour air dates but showed **Season 1** episode titles/stills (e.g. “Meeting the Goblins” with Apr 2026 dates).

## Root cause

`hubAnimeTmdbSeasonNumber` reads `meta.seasons[].selected`. Details put the rail on `data.seasons` only, and host enrich piped `meta` alone — so enrich defaulted to **TMDB Season 1**. AniList airing dates on the cour Media stayed, producing mixed S4 dates + S1 names.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I514-T01 | Pack details: copy season chips onto `meta.seasons` for enrich | ✅ |
| 2 | I514-T02 | Host enrich pipe: attach `data.seasons` onto enrich `meta` | ✅ |
| 3 | I514-T03 | Fallback: parse “Nth Season” from Media title when chips missing | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I514-A01 | Slime Season 4: E1 title is TMDB S4 (“New Days”), not S1 goblin eps | ✅ (logic: chip/title → season 4; TMDB S4 verified) |
| 2 | I514-A02 | Manual QA after soft-pull `forjahq-anime` 1.0.65+ + host rebuild | ⬜ |

## Links

- Pack: `forjahq-anime` **1.0.65**
- Host: `plugin_actions.dart` enrich meta seasons attach
