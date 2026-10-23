# 471 — Player Episodes panel: season dropdown + collapsible search

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Player · Episodes panel · Android TV D-pad  
**Reported:** 2026-10-23 (product: episodes by season + IPTV-style search)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. Hub / pack series Episodes panel lists every season in one flat scroll (repeating episode numbers / `S{n} E{m}` badges). Need episodes **for the selected season only**, with a season dropdown that works on D-pad.
2. Search field is always open and eats chrome space. Want a search **button** that expands the field (same idea as IPTV list search): tap/OK opens and focuses the input; on TV browse focus must not open the keyboard until OK.

## Root cause (verified in code)

- `PlayerEpisodePanel` (TMDB) already loads one season and shows `_SeasonDropdown` when `seasonCount > 1`.
- `PlayerKitEpisodePanel` (`_HubEpisodePanelBody`) takes a flat `episodes` list, chunks/search across all seasons, and only badges multi-season rows — no season filter / dropdown.
- `_EpisodeSearchAutoNextBar` always mounts a full-width search field (`TvBrowseTextField` on TV).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I471-T01 | Hub Episodes panel: season list from episode seasons, dropdown, filter list to selected season (D-pad edges) | ✅ |
| 2 | I471-T02 | Episode panel search: collapsed search button → expand + focus field; TV browse-until-activate (IPTV pattern) | ✅ |
| 3 | I471-T03 | Changelog + feature guide | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I471-A01 | Multi-season hub show: Episodes panel season dropdown changes the list to that season only; D-pad reaches dropdown, search, close, list | ⬜ |
| 2 | I471-A02 | Search starts as icon; OK/tap expands and focuses field; on TV keyboard only after activate on the field | ⬜ |

## Links

- [459](459-[open]-android-tv-series-journey-search-space-episode-ok-next-season.md) — season-aware next / badges (flat list still)
- [248](248-[open]-android-tv-player-episodes-search-dpad.md) — Episodes search D-pad
