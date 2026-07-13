# Services map

**Status:** living doc  
**Area:** `packages/rust/`, `apps/forja/lib/shared/`, `apps/forja/lib/features/`  
**Related:** [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) · [Feature file map](feature-file-map.md) · [RFC-020](../rfc/020-[draft]-media-details-routing.md)

## Placement rules

| Layer | Path | Owns |
|-------|------|------|
| **Rust engine** | `crates/*` | Fetch, parse, crypto, torrent, proxy, resolver race, persistence |
| **FFI bridge** | `packages/rust/lib/src/` | Thin Dart wrappers over engine — **not** new engine logic |
| **Host platform** | `apps/forja/lib/shared/services/` | OS intents, PiP, external player, OAuth UX, app updates |
| **Host adapters** | `apps/forja/lib/shared/extractors/`, `shared/nuvio/` | WebView (C3), `flutter_js` (C4), WASM host (C5) |
| **Host orchestration** | `apps/forja/lib/shared/playback/` | Provider-race UX, cache, resume handoff — calls engine + adapters |
| **Hub catalog** | `apps/forja/lib/features/<hub>/catalog/` | Vertical browse + stream orchestration for that tab only |
| **Media routes** | `apps/forja/lib/features/media/` | TMDB-global details + Stremio catalog **screens** (not services) |
| **Tab browse** | `apps/forja/lib/features/<tab>/` | Screen orchestrators + tab-private widgets |

**Default for new scrape/API work:** implement in `crates/*` → expose FFI → thin wrapper in `packages/rust`.  
**Exception:** WebView / JS / WASM stays in host adapter; feature `catalog/` may orchestrate only.

---

## Rust migration backlog (rechecked 2026-07)

### Current product scope (2026-07)

**In scope** — ship polish, Rust migration, and QA here only:

| Tab | Nav ID | Engine / catalog touchpoints |
|-----|--------|------------------------------|
| Home | `home` | TMDB browse, Stremio rails, BestSimilar home recs |
| Search | `search` | `TmdbApi` |
| Anime | `anime` | `AnimeService` → `anime-core` ✅ |
| Asian Drama | `asian_drama` | `KissKhService` → `kisskh-core` ✅ |
| Live Matches | `live_matches` | `live-matches-core` ✅ |
| IPTV | `iptv` | `iptv-core` Reddit + probe ✅ |
| Lists | `mylist` | `MyListService`, watch history (host + engine) |
| Settings | `settings` | Host prefs / platform |

**Out of scope for now** — do not schedule Rust ports or tab UX work unless explicitly reopened:

`discover`, `similar`, `arabic`, `anime_arabic`, `manga`, `comics`, `books`, `audiobooks`, `music`, `jellyfin`, `downloader`, `magnet`, and other shell tabs.

P1 rows below for Arabic / Anime Arabic / Audiobook / Comics are **⏭️ deferred** under this scope. Manga / Books / BestSimilar were ported earlier but are not active-tab priorities.

**Migration status for in-scope hubs:** P0 (anime + kisskh) ✅ · P2 (live matches + IPTV) ✅ · P3 thin orchestration ✅.

---

**~9k LOC** of Dart scrape/catalog logic remains in `apps/forja` (excluding permanent host adapters). HTTP already routes through engine FFI in most places; **parse + orchestration** is what should move when a tab is in scope.

### ✅ Shipped (P0 / P2 / P3 slice — 2026-07)

| Item | Crate / FFI | Dart after |
|------|-------------|------------|
| KissKh catalog API | `crates/kisskh-core` · `kisskh_catalog_json` | `kisskh_service.dart` — history + models + `KissKhExtractor` (C3) |
| Anime extractors (5) | `crates/anime-core/extractors/*` · `anime_extractor_json` | Deleted Dart extractors; `miruro_pipe_session.dart` stays host |
| Live matches fetch | `crates/live-matches-core` · `live_matches_fetch_json` | `live_matches_models.dart` — playback/embed host only |
| IPTV Reddit scraper | `crates/iptv-core/reddit_catalog` · `iptv_reddit_catalog_json` | `iptv_network.dart` — probe/session host |

| Anime Anikoto resolve + direct embed | `crates/anime-core/resolve/*` · `anime_extractor_json` | `anime_service.dart` — orchestration + cache only |

### ✅ Correct today — do not move

| Component | Location | Why |
|-----------|----------|-----|
| TMDB, Trakt, Jellyfin API calls | `packages/rust` + `crates/*-core` | C1 engine |
| Webstreamr, torrent, indexers, debrid, proxy | `crates/webstreamr`, `scrapers`, `debrid-core`, `proxy` | C2/C7 engine |
| AniList GraphQL | `runAnilistQueryJson` → `anilist-core` | C1 — `AnimeService._query` is thin |
| KissKh subtitle decrypt | `crates/utils/kisskh_subtitle` | Engine |
| Subtitles, mdblist, introdb, lyrics, paper2audio | `crates/anime-core` | Engine |
| Vidsrc extract | `VidsrcExtractor` → Rust resolve job | C2 engine |
| Manga HTTP fetch | `mangaFetchHtml` → `manga-core` | Fetch only — **parse still Dart** |
| Jellyfin HTTP | `runJellyfinRequestJson` → `jellyfin-core` | API in Rust; OAuth/cache/models stay host |
| IPTV probe | `runIptvProbeStreamJson` → `iptv-core` | Engine |
| IPTV Reddit catalog | `runIptvRedditCatalogJson` → `iptv-core` | Engine |
| KissKh catalog | `runKisskhCatalogJson` → `kisskh-core` | Engine |
| Anime extractors + resolve | `runAnimeExtractorJson` → `anime-core` | Engine |
| Live matches APIs | `runLiveMatchesFetchJson` → `live-matches-core` | Engine |
| Manga catalog | `runMangaCatalogJson` → `manga-core` | Engine |
| LibGen books | `runBooksCatalogJson` → `books-core` | Engine |
| BestSimilar catalog | `runCatalogCoreJson` → `catalog-core` | Engine |

### ❌ Permanent host — never port to Rust

| Component | LOC | Class | Reason |
|-----------|----:|-------|--------|
| `KissKhExtractor` | 503 | C3 | Obfuscated JS `kkey` — WebView only |
| `StreamExtractor` | 676 | C3 | Headless embed sniff |
| `AmriExtractor` | 275 | C3 | WebView |
| `NuvioService` / `NuvioScraper` | — | C4 | `flutter_js` |
| `VideasyExtractor` | 803 | C5 | WASM host (Rust plugin delegates back to host) |
| `TraktService` / `SimklService` | — | C12 | OAuth + secure storage |
| `PipService`, `ExternalPlayerService`, `PlayerPoolService`, `AppUpdaterService` | — | C6/C12 | Platform |
| `MusicPlayerService`, `AudiobookPlayerService`, storage/download | — | C6/C9 | Host playback + files |
| `CastingService`, `SyncService` | — | C12 | Platform / LAN |
| `PlaybackEngine`, `DomainStreamProviderResolver`, resume/cache | `shared/playback/` | C11 | Orchestration UX |

Arabic / Anime Arabic: **hybrid** — HTTP+PACKER parse → Rust; WebView fallback paths stay host.

---

### P0 — TV-scope hubs (ship first)

| Dart today | LOC | Target crate | Port scope | Keep on host | Status |
|------------|----:|--------------|------------|--------------|--------|
| `AllAnimeExtractor` | 379 | `anime-core/extractors/allanime` | AES decrypt, clock API, GraphQL persisted query | — | ✅ |
| `MiruroExtractor` + `miruro_pipe_session` | 576 | `anime-core/extractors/miruro` | Pipe session + stream URL parse | `miruro_pipe_session` (CF WebView) | ✅ |
| `AnimeRealmsExtractor` | 206 | `anime-core/extractors/animerealms` | HTML/JSON parse | — | ✅ |
| `HentainiExtractor` | 307 | `anime-core/extractors/hentaini` | HTML parse | — | ✅ |
| `WatchHentaiExtractor` | 351 | `anime-core/extractors/watchhentai` | HTML parse | — | ✅ |
| `AnimeService` (stream race slice) | ~280 of 1321 | `anime-core/resolve` | Anikoto resolve, megaplay/vidwish extract, stream probe | Watch-history prefs, embed build, stream race UX | ✅ |
| `KissKhService` | 571 | `kisskh-core` | JSON API browse/details/episode list parse | `KissKhExtractor` (C3) | ✅ |

**After P0:** `AnimeService` shrinks to orchestration (history, SUB/DUB prefs, calling engine jobs). `resolver-engine` already has `kisskh` host-required plugin — metadata port unblocks cleaner split.

---

### ✅ Shipped (P1 slice — 2026-07)

| Item | Crate / FFI | Dart after |
|------|-------------|------------|
| Manga weebcentral parse | `manga-core` · `manga_catalog_json` | `manga_service.dart` — likes + thin wrapper |
| LibGen books scrape | `books-core` · `books_catalog_json` | `books_service.dart` — thin wrapper |
| BestSimilar autocomplete + details | `catalog-core` · `catalog_core_json` | `bestsimilar_scraper.dart` — cache + models |

### P1 — Large vertical scrapers

| Dart today | LOC | Target crate | Notes | Status |
|------------|----:|--------------|-------|--------|
| `MangaService` | 453 → ~250 | `manga-core` | Parse weebcentral HTML (fetch+parse in Rust) | ✅ |
| `BooksService` | 245 → ~90 | `books-core` | Libgen-style HTML scrape | ✅ |
| `BestSimilarScraper` | 454 → ~230 | `catalog-core` | Autocomplete JSON + detail HTML parse | ✅ |
| `ArabicService` | 1365 | `arabic-core` (new) | Port PACKER/HTTP paths; keep `StreamExtractor` fallback as host adapter | ⏭️ |
| `AnimeArabicService` + `AnimeArabicExtractor` | 1242 | `anime-arabic-core` (new) | Browse/scrape parse → Rust; iframe/WebView paths → host | ⏭️ |
| `AudiobookService` + `audiobook_scrapers` | 1328 | `audiobook-core` (new) | Multi-platform HTML/API scrape | ⏭️ |
| `ComicsService` + scrapers | 1020 | extend `crates/proxy/comic` or `comics-core` | `ReadComicsOnlineScraper`, `ComicPageExtractor` | ⏭️ |

---

### P2 — IPTV + live matches + Jellyfin cleanup

| Dart today | LOC | Target | Notes | Status |
|------------|----:|--------|-------|--------|
| `IptvScraper` (in `iptv_network.dart`) | ~650 | `iptv-core` | Reddit OAuth + paste/M3U link scrape | ✅ |
| `live_matches_models.dart` fetch fns | ~200 | `live-matches-core` | Streamed.pk + CDN APIs | ✅ |
| `JellyfinService` models + OAuth | ~400 of 1272 | stay host | API already `runJellyfinRequestJson`; optional: move models to `packages/rust/models` | ✅ split |

---

### P3 — Thin Dart that looks fat (orchestration, not engine)

Keep in host — refactor only:

| Component | Role |
|-----------|------|
| `AnimeService` browse rails | Calls AniList engine + maps to `AnimeCard` |
| `KissKhService` watch history | `SharedPreferences` + calls engine for API |
| `StremioService` | Addon orchestration (P2-89); manifest parse can move incrementally |
| `JellyfinService` | Account OAuth, cache keys, session |
| `packages/rust/lib/src/playback/*_resolver.dart` | C11 glue to `resolver-engine` |

---

### Suggested port order (when scope expands)

In-scope hubs are **done** for the current arc. If a deferred tab reopens:

1. **Comics** → `comics-core` (RCO decode; WebView extractor stays host)
2. **Arabic PACKER paths** → `arabic-core` (split WebView adapter)
3. **Anime Arabic** → `anime-arabic-core`
4. **Audiobook** → `audiobook-core`

Already shipped (low priority tabs): manga, books, BestSimilar (`catalog-core`).

**Per-port checklist:** implement in `crates/*` → FFI → parity tests → **delete Dart slice** → hub `catalog/` becomes thin orchestration only.

---

| Service / API | Path | Capability | Target |
|---------------|------|------------|--------|
| `TmdbApi` / `TmdbService` | `catalog/tmdb_api.dart`, `tmdb_service.dart` | C1 TMDB | ✅ Engine |
| `StremioService` | `catalog/stremio_service.dart` | C1 addon catalog | ✅ Engine (orchestration thin in Dart OK) |
| `MusicService` | `catalog/music_service.dart` | C1 Deezer/YouTube | ✅ Engine |
| `MdblistService` | `catalog/mdblist_service.dart` | C1 lists API | ✅ Engine |
| `IntroDbService` | `catalog/introdb_service.dart` | C1 skip intro | ✅ Engine |
| `Paper2AudioService` | `catalog/paper2audio_service.dart` | C1 TTS API | ✅ Engine |
| `SubtitleApi` + `SubtitleCatService`, `MysubsService` | `catalog/subtitle_*.dart` | C1/C2 subtitles | ✅ Engine |
| `SettingsService` | `settings_service.dart` | C9 prefs | ✅ Engine |
| `WatchHistoryService` | `watch_history_service.dart` | C9 history | ✅ Engine |
| `MyListService` | `my_list_service.dart` | C9 lists | ✅ Engine |
| `BookProgressService` | `book_progress_service.dart` | C9 reading progress | ✅ Engine |
| `EpisodeWatchedService` | `episode_watched_service.dart` | C9 + tracker sync callback | ✅ Engine |
| `WebStreamrService` | `playback/webstreamr_service.dart` | C2 direct streaming | ✅ Engine |
| `JackettService` / `ProwlarrService` | `playback/jackett_service.dart`, `prowlarr_service.dart` | C2 indexers | ✅ Engine |
| `LinkResolver` | `playback/link_resolver.dart` | C2 magnet resolve | ✅ Engine |
| `DebridApi` | `playback/debrid_api.dart` | C2 debrid | ✅ Engine |
| `TorrentStreamService` | `playback/torrent_stream_service.dart` | C7 torrent playback | ✅ Engine |
| `LocalServerService` | `playback/local_server_service.dart` | C7 loopback | ✅ Engine |
| `Site111477Service` | `playback/site111477_service.dart` | C2 index + C7 proxy glue | ✅ Engine |
| `DeviceCapabilitiesService` | `playback/device_capabilities_service.dart` | C6 probe | ✅ FFI helper |

---

## Host platform services (`shared/services/`)

| Service | Path | Why host | Target |
|---------|------|----------|--------|
| `TraktService` | `tracker/trakt_service.dart` | C12 OAuth + token storage | ✅ Host |
| `SimklService` | `tracker/simkl_service.dart` | C12 OAuth | ✅ Host |
| `ExternalPlayerService` | `external_player_service.dart` | C6/C12 OS intents (VLC, etc.) | ✅ Host |
| `PlayerPoolService` | `player_pool_service.dart` | C6 player instance lifecycle | ✅ Host |
| `PipService` | `pip_service.dart` | C6 platform PiP | ✅ Host |
| `AppUpdaterService` | `app_updater_service.dart` | C12 GitHub releases / install | ✅ Host |

---

## Host adapters — permanent (`shared/extractors/`, `shared/nuvio/`)

| Component | Path | Capability | Port to Rust? |
|-----------|------|------------|---------------|
| `StreamExtractor` | `shared/extractors/stream_extractor.dart` | C3 WebView embed sniff | ❌ Host unless crypto reversed |
| `AmriExtractor` | `shared/extractors/amri_extractor.dart` | C3 WebView | ❌ Host |
| `ArabicService` | `shared/extractors/arabic_service.dart` | C2 multi-site scrape | 🔄 Port HTML parse to engine; keep WebView paths on host |
| `NuvioService` / `NuvioScraper` | `shared/nuvio/nuvio_service.dart` | C4 `flutter_js` | ❌ Permanent host |
| `VideasyExtractor` | `packages/rust/.../videasy_extractor.dart` | C5 WASM | ❌ WASM host in Dart |

---

## Host orchestration (`shared/playback/`, `shared/audio/`, `shared/catalog/`)

| Component | Path | Role | Target |
|-----------|------|------|--------|
| `PlaybackService` / `PlaybackEngine` | `shared/playback/` | C11 resolve UX, guards, cache | ✅ Host orchestration |
| `DomainStreamProviderResolver` | `domain_playback_resolve.dart` | C11 domain → engine jobs | ✅ Host |
| `WebstreamingStreamCache` | `webstreaming_stream_cache.dart` | C11 session cache | ✅ Host |
| `HistoryPlaybackResume` | `history_playback_resume.dart` | C11 resume routing | ✅ Host |
| `BestSimilarScraper` | `shared/catalog/bestsimilar_scraper.dart` | C2 TMDB-adjacent recs | 🔄 Port to `crates/*` when touched |
| `MusicPlayerService` | `shared/audio/music_player_service.dart` | C6 audio playback UI glue | ✅ Host |
| `MusicStorageService` / `MusicDownloaderService` | `shared/audio/` | C6/C9 local files | ✅ Host |
| `LyricsService` | `shared/audio/lyrics_service.dart` | C1 via engine | ✅ Thin host over engine |
| `AudiobookPlayerService` / `AudiobookDownloadService` | `shared/audio/` | C6 host playback | ✅ Host |
| `CastingService` | `shared/casting/` | C12 AirPlay/Chromecast (RFC-005) | ✅ Host |
| `SyncService` | `shared/sync/` | C12 LAN sync (RFC-013) | ✅ Host |

---

## Hub catalog services (`features/*/catalog/`)

Each hub owns **vertical browse + stream orchestration** for its tab. Metadata fetch should call engine FFI; extractors that are pure HTTP+parse should move to `crates/*` over time.

| Service | Feature | Engine parts | Host parts | Action |
|---------|---------|--------------|------------|--------|
| `AnimeService` | `anime/catalog/` | AniList GraphQL + extractors + Anikoto resolve (Rust) | `miruro_pipe_session`, history prefs, stream race UX | ✅ |
| `KissKhService` | `asian_drama/catalog/` | `kisskh-core` catalog API | `KissKhExtractor` (WebView C3), watch history | ✅ |
| `MangaService` | `manga/catalog/` | `manga-core` fetch+parse | Likes (`SharedPreferences`) | ✅ |
| `BooksService` | `books/catalog/` | `books-core` | — | ✅ |
| `BestSimilarScraper` | `shared/catalog/` | `catalog-core` | TMDB poster enrichment in home/similar screens | ✅ |
| `AnimeArabicService` | `anime_arabic/catalog/` | Mega proxy (Rust) | `AnimeArabicExtractor` (iframe scrape) | Port parse → engine where possible |
| `ArabicService` | `shared/extractors/` (used by `arabic/`) | — | Multi-site C2 + WebView fallback | ⬜ `arabic-core` |
| `ComicsService` + `ReadComicsOnlineScraper` | `comics/catalog/` | — | C2 scrape | Port → engine |
| `BooksService` | `books/catalog/` | — | C2 scrape | Port → engine |
| `AudiobookService` | `audiobooks/catalog/` | Platform APIs partial Rust | Scrape orchestration | Port → engine |
| `JellyfinService` | `jellyfin/catalog/` | API in Rust | OAuth/session host | ✅ Split correct |

---

## Feature modules — screens, not services

| Module | Path | Role |
|--------|------|------|
| **Home** | `features/home/` | TMDB/Stremio browse tab only — `home_screen`, `home_hero`, `widgets/` |
| **Media** | `features/media/` | Global TMDB details + Stremio catalog routes |
| **Search** | `features/search/` | TMDB search — uses `TmdbApi`, `AppRouter.openDetails` |
| **Anime / Asian Drama** | `features/anime/`, `features/asian_drama/` | Hub screens + `catalog/` + feature details/player |

---

## Decision guide — where does new code go?

```
Need HTTP + HTML/JSON parse + crypto?
  → crates/<domain>/ + FFI in packages/rust

Need WebView, page JS, or WASM?
  → apps/forja/shared/extractors/ or shared/nuvio/
  → Feature catalog/ calls adapter; returns normalized StreamSource

Need OAuth, PiP, external player, file picker?
  → apps/forja/shared/services/

Need provider race progress UI, resume, panel state?
  → apps/forja/shared/playback/ or feature screen

Hub-only browse + episode list for one vertical?
  → features/<hub>/catalog/<hub>_service.dart

TMDB-global details or Stremio full catalog route?
  → features/media/ (screen) + engine services via packages/rust
```

---

### Hub browse widgets (`features/<hub>/widgets/`)

| Feature | Widgets |
|---------|---------|
| **Anime** | `anime_widget_imports.dart`, `anime_continue_watching_card.dart`, `anime_continue_watching_section.dart` |
| **Asian Drama** | `asian_drama_widget_imports.dart`, `asian_drama_continue_watching_card.dart`, `asian_drama_continue_watching_section.dart` |
| **Home** | `home_widget_imports.dart`, `continue_watching_section.dart`, `home_mood_section.dart`, … |

Hub screens stay thin orchestrators (`*_screen.dart` + feed/build mixins); tab-private section UI lives under `widgets/`.

---

| From | To |
|------|-----|
| `features/home/details_screen*.dart` | `features/media/details/` |
| `features/home/widgets/details_collection_section.dart` | `features/media/details/widgets/` |
| `features/home/stremio_catalog_screen.dart` | `features/media/stremio_catalog_screen.dart` |

Entry: `AppRouter.openDetails` → `features/media/details/details_screen.dart`.  
Home retains browse-only: `home_screen`, `home_hero`, `home_screen_feed/build`, `widgets/`.
