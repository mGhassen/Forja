# 448 — My List kind filter empty + pin wrong on Simkl rows

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** My List hub · poster grid · list status pin

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6 / 6** fix · **0 / 1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I448-T01 | Kind menu defaults to Film (`movie`) so the grid is not unfiltered on open | ✅ |
| 2 | I448-T02 | Card type label is FILM / TV / ANIME / DRAMA — not hub name (HOME / AFLEM) | ✅ |
| 3 | I448-T03 | Poster pin passes feed `listStatus` as `knownStatus` when local bookmark is missing | ✅ |
| 4 | I448-T04 | Pack paint puts `listStatus` on poster props for pin fallback | ✅ |
| 5 | I448-T05 | Revert Film default — empty kind = all titles (Film-only hid most lists) | ✅ |
| 6 | I448-T06 | Pin display: exact uid → feed knownStatus → loose TMDB (stop wrong plantowatch on Watching) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I448-A01 | Watching tab cards show green Watching pin; Plan to Watch yellow; no bare + when the row is on that tab | ⬜ |

---

## Summary

My List kind menu had no default and `toggle: true`, so an empty selection painted every kind. Card footers used `hubLabel` for non-TMDB opens (HOME / AFLEM). Poster pins read only `BookmarkStore`, so Simkl-only rows on a status tab showed `+`.

Defaulting kind to Film made lists that are mostly Series/Anime/Drama look wiped — reverted; no kind selected = show all.

Pin still showed Plan to Watch / + on Watching cards because loose TMDB resolve preferred another hub’s plantowatch alias over the feed row’s `listStatus`.
