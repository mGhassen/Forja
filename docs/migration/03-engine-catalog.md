# Phase 3 — Catalog engine (wave 2)

**Status:** 4 / 5 tasks — P3-04 in progress  
**Depends on:** [Playback engine exit checklist](./02-rust-engine-complete.md#playback-engine-exit-checklist) ✅  
**Next phase:** [Phase 4 — Web client](./04-web-client.md) (parallel)  
**Migration index:** [README.md](./README.md)  
**Boundary:** [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

---

## Goal

Catalog engine lives in `crates/*`. Delete `packages/api` and any remaining legacy engine under `packages/`.

TMDB, Trakt, Jellyfin, and vertical APIs are **C1 engine** — same destination as playback (`crates/*`), different wave. ~~`packages/api`~~ **deleted** (P3-03 ✅); residual Dart engine debt lives in `apps/forja` until ported.

---

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 5 tasks** — P3-04 in progress |
| **Blocked by** | — |
| **Deferred from wave 1** | P2-89 (Stremio catalog service) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | P3-00 | Delete `packages/kotlin/` + `scripts/generate_kotlin_ffi.sh` references (Compose cancelled) | ✅ |
| 2 | P3-01 | Port TMDB/Trakt core to `crates/*` | ✅ |
| 3 | P3-02 | Port verticals incrementally (anime, manga, jellyfin, music, Arabic, …) | ✅ |
| 4 | P3-03 | Delete `packages/api` | ✅ |
| 5 | P3-04 | Architecture normalized sign-off | 🔄 |

### P3-03 — done

`packages/api` deleted. Final relocation: playback/debrid/torrent services → `apps/forja/lib/shared/playback/`; `music_service` → `apps/forja/lib/shared/audio/`; `jellyfin_service` → `apps/forja/lib/features/jellyfin/catalog/`; `subtitle_api` → `packages/rust/lib/src/catalog/`. See [023-[fixed]-packages-api-delete-blocked-host-relocation.md](../issues/fixed/023-[fixed]-packages-api-delete-blocked-host-relocation.md).

| Step | Status |
|------|--------|
| Move `anime_http.dart` → `packages/rust/lib/src/catalog_http.dart` | ✅ |
| Move shared DTOs (`Movie`, `StreamSource`, `TorrentResult`) → `packages/rust/lib/src/models/` | ✅ |
| Move host services (`pip`, `external_player`, `player_pool`, `android_player_launcher`, `app_updater`) → `apps/forja/lib/shared/services/` | ✅ |
| Move `episode_watched_service` → `packages/rust` (Trakt/Simkl sync via host callback) | ✅ |
| Move `my_list_service` + `book_progress_service` → `packages/rust`; `BookResult` → `packages/rust/lib/src/models/` | ✅ |
| Consolidate tracker sync in `apps/forja/lib/shared/services/tracker_sync.dart` | ✅ |
| Move playback glue (11 files) + `webstreamr_settings` → `packages/rust/lib/src/playback/` | ✅ |
| Move catalog metadata services → `packages/rust/lib/src/catalog/` | ✅ |
| Move host utils + music/audio cluster → `apps/forja` | ✅ |
| Move catalog verticals + extractors → `apps/forja` | ✅ |
| Relocate final 14 files (playback resolvers, debrid, music, jellyfin, subtitle) | ✅ |
| Remove `packages/api` from workspace | ✅ |

### P3-04 — in progress

Consolidate residual Dart engine into `packages/rust`; port direct-`http` slices to `crates/*` for A2/A4.

| Step | Status |
|------|--------|
| Move playback Dart from `apps/forja/lib/shared/playback/` → `packages/rust/lib/src/playback/` | ✅ |
| Move `music_service` + `youtube_audio_extractor` → `packages/rust/lib/src/catalog/` | ✅ |
| Port jackett / prowlarr / link_resolver → `crates/indexer-core` + FFI | ✅ |
| Port debrid (5 providers) → `crates/debrid-core` + FFI | ✅ |
| Port site111477 index scrape → `crates/proxy/index111477` + FFI | ✅ |
| Port mega_proxy → `crates/proxy/mega` + FFI | ✅ |
| Port music_service → `crates/music-core` + FFI | ✅ |
| Port lyrics + introdb → `anime-core/metadata` + FFI | ✅ |
| Port mdblist → `anime-core/mdblist` + FFI | ✅ |
| Port paper2audio → `anime-core/paper2audio` + FFI | ✅ |
| Port subtitle stack (wyzie, levrx, subtitlecat, mysubs) → `anime-core/subtitle` + FFI | ✅ |
| Document host exceptions (WebView/C3 extractors) | ✅ |
| A2 + A4 exit checklist green | ⬜ |

---

## Catalog engine exit checklist {#exit-checklist}

**Architecture fully normalized when all rows are ✅.**

| # | Criterion | Task | Status |
|---|-----------|------|--------|
| A1 | `packages/api` deleted | P3-03 | ✅ |
| A2 | All C1 catalog logic in `crates/*` | P3-01, P3-02 | ⬜ |
| A3 | Only `packages/rust` under `packages/` | P3-03, P3-04 | ✅ |
| A4 | No engine logic in Dart outside FFI calls | P3-01 → P3-03 | ⬜ |
| A5 | `packages/kotlin` deleted | P3-00 | ✅ |

---

## Migration rule

| Step | Action |
|------|--------|
| 1 | Port vertical to `crates/<vertical>/` or shared catalog crate |
| 2 | Add FFI in `crates/ffi` (fetch+parse, Pattern B) |
| 3 | Wire `apps/forja` to `ForjaEngine.*` |
| 4 | **Delete the Dart slice** — directory, pubspec deps, imports |
| 5 | Rust tests + Dart parity in `packages/rust/test/parity/` where applicable |

**No new engine logic in Dart** during wave 2.

### Port order (suggested)

```mermaid
flowchart LR
  P300["P3-00 delete kotlin"]
  P301["P3-01 TMDB Trakt core"]
  P302["P3-02 verticals"]
  P303["P3-03 delete api"]
  P304["P3-04 sign-off"]

  P300 --> P301 --> P302 --> P303 --> P304
```

| Vertical | Current location | Target crate |
|----------|------------------|--------------|
| TMDB | `packages/rust` (FFI) | `crates/tmdb-core` ✅ |
| Trakt | `apps/forja` (OAuth) + `crates/trakt-core` | `crates/trakt-core` ✅ |
| Jellyfin | `apps/forja/features/jellyfin/catalog/` (FFI) | `crates/jellyfin-core` ✅ |
| Anime (AniList + HTTP) | `apps/forja/features/anime/catalog/` + `crates/anilist-core` | ✅ |
| KissKh metadata | `apps/forja/features/asian_drama/catalog/` | `crates/anime-core` ✅ |
| Arabic (Larozaa/DimaToon/Brstej) | `apps/forja/shared/extractors/` | `crates/anime-core` ✅ |
| Books (LibGen) | `apps/forja/features/books/catalog/` | `crates/anime-core` ✅ |
| Comics (RCO) | `apps/forja/features/comics/catalog/` | `crates/anime-core` ✅ |
| Manga (WeebCentral fetch) | `apps/forja/features/manga/catalog/` | `crates/manga-core` ✅ |
| Anime Arabic (AnimeSlayer) | `apps/forja/features/anime_arabic/catalog/` | `crates/anime-core` ✅ |
| Subtitles/metadata | `packages/rust/lib/src/catalog/` | `crates/anime-core` ✅ |
| Audiobook (browse/search) | `apps/forja/features/audiobooks/catalog/` | `crates/anime-core` ✅ |
| Paper2Audio | `anime-core/paper2audio` + thin Dart FFI | ✅ |
| Lyrics (LRCLIB) | `anime-core` metadata + thin Dart FFI | ✅ |
| IntroDB skip timestamps | `anime-core` metadata + thin Dart FFI | ✅ |
| Debrid (RD/TorBox/AD/PM/DL) | `crates/debrid-core` + thin Dart FFI | ✅ |
| Site111477 index scrape | `crates/proxy/index111477` + thin Dart FFI | ✅ |
| Site111477 seek proxy | `crates/proxy/seek111477` + `site111477_proxy.dart` | ✅ |
| mega_proxy | `crates/proxy/mega` + thin Dart FFI | ✅ |
| Jackett / Prowlarr / link resolver | `crates/indexer-core` + thin Dart FFI | ✅ |
| Music (Deezer + YouTube InnerTube) | `crates/music-core` + thin Dart FFI | ✅ |

### `packages/` after wave 2

| Package | Purpose |
|---------|---------|
| `packages/rust` | Dart FFI bridge + parity tests (**permanent**) |
| `packages/rust/lib/src/catalog_http.dart` | Shared catalog HTTP (`animeHttp` / `animeHttpBytes`) — moved from `packages/api` in P3-03 |
| `packages/rust/lib/src/models/` | Shared DTOs (`Movie`, `StreamSource`, `TorrentResult`) — moved from ~~`packages/api`~~ in P3-03 |
| `packages/rust/lib/src/playback/` | Thin FFI wrappers (debrid, indexers, site111477, mega) |
| `crates/proxy` | Local proxy + site111477 index/seek + mega decrypt proxy |
| `crates/indexer-core` | Jackett + Prowlarr + link resolve (P3-04) |
| `crates/debrid-core` | Debrid resolve — 5 providers (P3-04) |
| `packages/rust/lib/src/catalog/` | Catalog metadata + thin `music_service`, `subtitle_api` |
| `crates/music-core` | Deezer catalog + YouTube InnerTube audio (P3-04) |

---

## Host exceptions (C3–C5) — documented, not ported

Per [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) §3, these **stay in `apps/forja`** (WebView / JS / WASM hosts). HTTP fetch uses `animeHttp` → `anime-core`; parse/orchestration in Dart is host-side until ported.

| Area | Files | Class | Notes |
|------|-------|-------|-------|
| KissKh WebView | `asian_drama/catalog/kisskh_extractor.dart` | C3 | WebView embed sniff |
| Allanime / Miruro / Hentaini | `anime/catalog/*_extractor.dart` | C2+C3 | HTML parse in Dart; HTTP via FFI |
| Arabic verticals | `shared/extractors/arabic_service.dart` | C2 | Multi-site scrape in Dart |
| Anime Arabic | `anime_arabic/catalog/anime_arabic_extractor.dart` | C2+C3 | Mega Rust; iframe scrape Dart |
| Nuvio | `shared/nuvio/nuvio_runtime.dart` | C4 | `flutter_js` |
| Videasy | `packages/rust/.../videasy_extractor.dart` | C5 | WASM host |
| Subtitle browse (SubtitleCat, MySubs, Wyzie, Levrx) | `anime-core/subtitle` + thin Dart FFI | ✅ |
| MDBlist | `anime-core/mdblist` + thin Dart FFI | ✅ |

**A4 not green:** C3 WebView extractors remain Dart host. Subtitle orchestrator (`subtitle_api.dart`) + Stremio addon calls stay thin Dart.

---

## Architecture

```
UI (apps/forja — Flutter permanent host)
  → widgets, navigation, OAuth, secure storage
  → calls ForjaEngine / RustLib for catalog paths

Engine (crates/* + libffi)
  → catalog: tmdb, trakt, jellyfin, vertical APIs
  → playback: stream resolve, torrent, proxy, storage (wave 1 ✅)

packages/rust/lib/src/playback/
  → thin FFI wrappers (P3-04 playback ✅)
packages/rust/lib/src/catalog/
  → thin music_service FFI; catalog vertical extractors remain in apps/forja (P3-04)
```

| **Engine (`crates/*`)** | **Host (`apps/forja`)** |
|-------------------------|-------------------------|
| TMDB/Trakt/Jellyfin fetch+parse | Browse UI, details screens |
| Vertical APIs (anime, manga, …) | OAuth flows, theme |
| Stremio catalog (P2-89 → P3) | My list UX, navigation |

**Allowed:** `Isolate.run` for long FFI · no **new** Dart engine logic in host

**Anti-patterns:** sync FFI on UI thread · Pattern A FFI · new engine logic in Dart

---

## Quick health check

```bash
./scripts/build_rust.sh
cd crates && cargo test --workspace
cd packages/rust && flutter test test/parity/tmdb_test.dart test/parity/trakt_test.dart test/parity/jellyfin_test.dart test/parity/anilist_manga_test.dart test/parity/anime_test.dart

# After each vertical port — grep for deleted Dart slice:
rg "packages/api/lib/api/<vertical>" apps/forja packages/rust
```

---

## Related

- [Phase 2 playback](./02-rust-engine-complete.md) · [Phase 4 web](./04-web-client.md) · [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) · [RFC-009](../rfc/009-rust-ffi.md)
