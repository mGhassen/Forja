# RFC-054 — Torrent search providers

**Status:** partial  
**Depends on:** —  
**Area:** Sources / torrent search

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **5 / 6** acceptance |
| **Current slice** | Providers + Settings toggles shipped — desktop smoke remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R54-C01 | Rust provider registry + search fan-out with enabled filter | ✅ |
| 2 | R54-C02 | Settings persistence + checkable provider list | ✅ |
| 3 | R54-C03 | FFI / Dart search request (`query` + `enabled` + optional IMDb) | ✅ |
| 4 | R54-C04 | Torrent panel shows `source` provider badge | ✅ |

---

## Acceptance (providers slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R54-A01 | Builtin search covers Knaben, Pirate Bay, UIndex, Torrents CSV, Nyaa, YTS, SolidTorrents, TheRARBG, Torrentio | ✅ |
| 2 | R54-A02 | Settings → Sources lists providers with on/off toggles; disabled providers are not queried | ✅ |
| 3 | R54-A03 | Results dedupe by infohash (keep higher seeders) and sort by seeders | ✅ |
| 4 | R54-A04 | Torrent panel tiles show provider `source` badge | ✅ |
| 5 | R54-A05 | Torrentio runs when IMDb id is available (movie / SxE) | ✅ |
| 6 | R54-A06 | Desktop smoke: toggle off Knaben → search → no Knaben rows | ⬜ |

---

## Summary

Expand Forja’s fixed 3-scraper torrent search into a checkable multi-provider set (public indexers + Torrentio), controlled from Settings and labeled in the torrent panel.

## Goals

- Parallel keyword search across enabled providers
- Per-provider enable in Settings (default: all on)
- Honest `source` labels on each result
- Engine logic stays in `crates/scrapers` (no Dart scrapers)

## Contracts

- Provider ids: `knaben`, `pirate_bay`, `uindex`, `torrents_csv`, `nyaa`, `yts`, `solid_torrents`, `therarbg`, `torrentio`
- Search request JSON: `{ "query", "enabled": [...], "imdb_id"?, "season"?, "episode"? }`
- Soft-fail per provider; empty provider → empty list, not error
- Settings key: `enabled_torrent_providers` (JSON string array)

## Related

- [Torrent scrapers](../features/scrapers/torrent.md)
- [Torrent settings](../features/settings/torrent-settings.md)
