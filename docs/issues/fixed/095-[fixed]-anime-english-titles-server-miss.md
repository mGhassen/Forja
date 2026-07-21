# 095 — Anime English titles + server miss on SPECIALS

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Anime

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** fix · **0/1** smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I95-T01 | Settings → Playback → Anime title language (Romaji default / English / Native) | ✅ |
| 2 | I95-T02 | Fetch AniList `synonyms`; `resolveTitleCandidates` romaji → english → native → synonyms | ✅ |
| 3 | I95-T03 | Anikoto resolve: candidate list + do not demote special/ova slugs when AniList format is SPECIAL/OVA/… | ✅ |
| 4 | I95-T04 | AllAnime / player embeds use `resolveTitleCandidates` | ✅ |
| 5 | I95-T05 | Feature docs + changelog + unit tests | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I95-A01 | Play AniList 1905 (*Harukanaru Toki no Naka de: Hachiyou Shou Specials* / Character Endings) finds at least one server | ⬜ |

---

## Summary

Catalog showed AniList **English** first. Title-search providers (Anikoto / AllAnime) queried English before romaji and **never** sent synonyms. Anikoto also **skipped** `special`/`ova` slugs when `expected_episodes > 1`, which killed legitimate SPECIALS (e.g. Character Endings, 8 eps).

**Root fix:** romaji-default display setting; synonym fan-out; romaji-first scrape candidates; side-slug demotion only for TV (not when AniList format is SPECIAL/OVA/ONA/MOVIE/…).

## Related

- [Anime](../features/hubs/anime.md)
- [Playback settings](../features/settings/playback-settings.md)
