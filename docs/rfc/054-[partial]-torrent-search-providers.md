# RFC-054 — Torrent search providers

**Status:** partial  
**Depends on:** —  
**Area:** Sources / torrent search

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** components · **15 / 16** acceptance |
| **Current slice** | Anime + Asian Drama `open.torrentEp` + IMDb enrich — desktop smoke R54-A06 remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R54-C01 | Rust provider registry + search fan-out with enabled filter | ✅ |
| 2 | R54-C02 | Settings persistence + checkable provider list | ✅ |
| 3 | R54-C03 | FFI / Dart search request (`query` + `enabled` + optional IMDb) | ✅ |
| 4 | R54-C04 | Torrent panel shows `source` provider badge | ✅ |
| 5 | R54-C05 | Progressive per-provider search — panel paints as each provider returns | ✅ |
| 6 | R54-C06 | Checking provider chips show the same cycling `…` as the kind tab | ✅ |
| 7 | R54-C07 | `plugins/torrent/` pack — nine `kind: torrent` JS indexers + manifest | ✅ |
| 8 | R54-C08 | `EngineRuntime.search` + `EngineService.runTorrentSearch` host path | ✅ |
| 9 | R54-C09 | Dynamic provider list from installed torrent pack (`TorrentSearchCatalog`) | ✅ |

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
| 7 | R54-A07 | Sources torrent list updates as each enabled provider returns (not wait-for-all) | ✅ |
| 8 | R54-A08 | While an indexer is still searching, that provider chip shows the same animated `…` as the Torrents tab | ✅ |
| 9 | R54-A09 | App search uses JS torrent plugins when the ForjaHQ Torrent pack is installed | ✅ |
| 10 | R54-A10 | Title filter, normalize, and magnet playback stay on Rust (`filter_torrents`, torrent engine) | ✅ |
| 11 | R54-A11 | Indexer on/off only in ForjaHQ Torrent pack expansion — duplicate Settings torrent providers group removed | ✅ |

---

## Acceptance (anime hub slice — appended)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 12 | R54-A12 | Anime TMDB enrich sets `ids.imdb` from TMDB external ids | ✅ |
| 13 | R54-A13 | Packs may set `open.torrentEp` so Sources searches `Title 05` / `Title - 05` | ✅ |
| 14 | R54-A14 | Hub `Movie.imdbId` carries enrich IMDb so Torrentio can run | ✅ |
| 15 | R54-A15 | Asian Drama pack sets `open.torrentEp` + enrich `ids.imdb` | ✅ |
| 16 | R54-A16 | Torrent Sources search consumes [RFC-079](079-[open]-sources-id-middleware.md) id bag (`imdb` + opaque `ids`) | ✅ |

---

## Acceptance (JS pack slice — appended)

See rows R54-A09–R54-A10 above. Frozen rows R54-C01–R54-A08 keep historical status; search execution moved off `crates/scrapers` FFI for the Flutter host (LAN server may still call Rust search until migrated).

---

## Summary

Expand Forja’s fixed 3-scraper torrent search into a checkable multi-provider set (public indexers + Torrentio), controlled from Settings and labeled in the torrent panel.

## Goals

- Parallel keyword search across enabled providers
- Paint torrent rows as each provider returns (slow indexer does not hold the list empty)
- Per-provider enable in Settings (default: all on)
- Honest `source` labels on each result
- Indexer search in hot-updatable JS (`plugins/torrent/`); filter / normalize / playback stay in Rust

## Contracts

- Provider ids: `knaben`, `pirate_bay`, `uindex`, `torrents_csv`, `nyaa`, `yts`, `solid_torrents`, `therarbg`, `torrentio`
- Search request JSON: `{ "query", "enabled": [...], "imdb_id"?, "season"?, "episode"? }`
- Soft-fail per provider; empty provider → empty list, not error
- Indexer enable follows pack + per-plugin toggle (`EnginePlugin.enabled`); legacy `enabled_torrent_providers` prefs key dropped

## Related

- [RFC-079](079-[open]-sources-id-middleware.md) — Sources id bag middleware (torrent consumes shared mapper)
- [Torrent scrapers](../features/scrapers/torrent.md)
- [Torrent settings](../features/settings/torrent-settings.md)
- [Issue 216](../issues/fixed/216-[fixed]-anime-hub-torrent-search-empty.md) — anime empty torrents
