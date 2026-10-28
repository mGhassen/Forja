# 515 — Anime torrent search uses bloated season title (Nyaa 0 rows)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Sources · torrent search · anime (`open.torrentEp`)  
**Reported:** 2026-10-28 (Slime 4th Season Part 1 & 2 ep01 → Nyaa/Knaben/Pirate Bay 0 rows; browser `Tensei Shitara s04e01` hits)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Anime Sources → Torrents returns empty for multi-season AniList titles. Indexers get the full cour name plus absolute `01` (e.g. `Tensei Shitara Slime Datta Ken 4th Season Part 1 & 2 01`). Nyaa AND-matches every token → 0. Short `… S04E01` finds releases.

## Root cause

1. `tvTorrentSearchPasses(torrentEp: true)` only builds `Title 05` / `Title - 05` (issue 216) — no `SxxExx`.
2. Query title is the AniList cour display name (includes `4th Season Part 1 & 2`), not a base series name.
3. Host season is media-local `1`; franchise season lives on the season chip label (`Season 4` → `S04`).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I515-T01 | Strip season/part fluff from torrent search base title | ✅ |
| 2 | I515-T02 | `torrentEp` passes: base + `SxxExx` (chip/title season) then absolute `Title 05` | ✅ |
| 3 | I515-T03 | Soft-drop rows whose scene S/E disagrees with target | ✅ |
| 4 | I515-T04 | Unit tests for base title, season resolve, pass list, soft filter | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I515-A01 | Slime 4th Season ep1 Sources → Torrents returns Nyaa (or other text) rows for `… S04E01` shape | ⬜ |
| 2 | I515-A02 | Non-`torrentEp` TV still searches `Title Sxx` / `SxxExx` unchanged | ⬜ |

## Links

- [216](fixed/216-[fixed]-anime-hub-torrent-search-empty.md) — introduced absolute-only `torrentEp`
- [RFC-054](../rfc/054-[partial]-torrent-search-providers.md)
