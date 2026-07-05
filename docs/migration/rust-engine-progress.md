# Rust engine migration — progress tracker

**Last updated:** 2026-07-05  
**Branch:** `feat/rust-migratiom` (typo in branch name)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)  
**Blockers:** [rust-engine-blockers.md](./rust-engine-blockers.md)  
**Plan:** `.cursor/plans/rust_kotlin_migration_*.plan.md` (local, not versioned)

---

## Status at a glance

**Goal:** same Forja experience on every platform. Rust is the engine everywhere Flutter runs natively; Dart reference code stays as an internal fallback until parity is proven — never a user-facing “off” switch.

**Where we are:** Steps 0–7 done. Mobile Rust build pipeline started (iOS/Android parsers). Step 9 cleanup in progress.

### Three columns — read every table this way

| Column | Question |
|--------|----------|
| **Rust** | Code exists in `crates/` + exposed via FFI? |
| **App** | Running app calls Rust when native library loads? |
| **Dart removed** | Old duplicate deleted? (always **no** until Step 9) |

Rust can be **yes** while App is **no** — code exists but the app still uses Dart.

**Done = ✅** when every module row in the step detail table is ✅/✅. HTTP fetch, page fetch, and registry staying in Dart is normal — same as scrapers — and does **not** block ✅.

### Migration phases

| Phase | What | Status |
|-------|------|--------|
| **A** | Rust crates in `crates/` | done |
| **B** | Dart FFI bridge `packages/forja_rust/` + parity tests | done |
| **C** | Flutter call sites wired in the app | done |
| **D** | Delete Dart duplicates | in progress |

Step 9 blockers → [rust-engine-blockers.md](./rust-engine-blockers.md)

### Feature matrix

| Area | Rust | App | Notes |
|------|:----:|:---:|-------|
| **0 — Scaffold** (build, FFI, CI) | ✅ | ✅ | desktop + mobile build scripts |
| **1 — Utils** (episode match, HLS, torrent filter) | ✅ | ✅ | all 5 modules wired |
| **2 — Stream URLs** | ✅ | ✅ | all 5 template providers wired |
| **3 — IPTV** | ✅ | ✅ | M3U, paste.sh, EPG decode, Xtream JSON parse |
| **4 — Stremio** | ✅ | ✅ | URL helpers + JSON parse + HTTP fetch wired |
| **5 — Webstreamr** | ✅ | ✅ | 23/23 extractors · 21/21 sources wired; fetch/registry stays Dart |
| **6 — Scrapers** | ✅ | ✅ | HTML parse + dedup; HTTP fetch stays Dart |
| **7 — Torrent + proxy** | ✅ librqbit | ✅ | Rust torrent playback when engine on · libtorrent fallback |
| **8 — Flutter integration** | N/A | N/A | `ForjaEngine.init()`, delegates, dylib bundling |
| **9 — Cleanup** | — | partial | 9/11 done — [details](#step-9--cleanup) · blockers [doc](./rust-engine-blockers.md) |

### What runs in Rust today

When boot log shows `[ForjaEngine] Rust engine v0.1.0`:

- IPTV: M3U parse, paste.sh decrypt, Xtream EPG decode, Xtream categories/streams/series episodes JSON
- Streaming: embed URLs for all 5 template providers (VidLink, VixSrc, Vidnest, Vidzee, VidRock)
- Utils: episode file matching, HLS master parse, torrent title filter, JS unpack, KissKH subtitle decrypt
- Stremio: URL building + manifest/stream/catalog/meta HTTP + JSON parse
- Scrapers: Knaben / TPB / Uindex HTML parse + dedup
- Webstreamr: 23 extractors + 21 sources (parse/extract via Rust when engine on)
- Local proxy: `/proxy?url=` + Range streaming (Rust backend; shelf forwards when engine on)
- Torrent playback: magnet → HTTP stream via librqbit (Rust when engine on)

### Platform parity

| Platform | Rust library | Torrent playback | Notes |
|----------|--------------|------------------|-------|
| macOS / Linux / Windows | `libforja_ffi` full features | librqbit (Rust) · libtorrent fallback | `./scripts/build_rust.sh` |
| iOS / Android | `libforja_ffi` parsers (no librqbit in FFI yet) | `libtorrent_flutter` | `./scripts/build_rust_mobile.sh` |

**Android release build with Rust bundled:**
```bash
./scripts/build_rust_mobile.sh android
# or: FORJA_BUILD_RUST_ANDROID=1 flutter build apk
# or: set forjaBuildRust=true in apps/forja/android/gradle.properties
```

Boot always calls `ForjaEngine.init()` — no disable toggle. If the native library is missing, Dart reference + libtorrent keep features working.

### Stays Dart (by design)

- Webstreamr: fetcher, registry, search/redirect orchestration (page HTTP)
- Scrapers: search HTTP fetch
- HLS proxy (`/hls-proxy`: m3u8 rewrite + PNG strip)
- Torrent playback on mobile (`libtorrent_flutter`; Rust torrent FFI desktop-only until librqbit mobile)
- Torrent playback when Rust dylib missing on desktop (`libtorrent_flutter` fallback)

### Numbers

| Metric | Value |
|--------|-------|
| Rust crates | 9 (8 domain + `forja-ffi`) |
| Stream providers wired | 5 / 5 |
| Webstreamr extractors ported | 23 / 23 |
| Webstreamr URL sources ported | 21 / 21 |
| Dart parity tests | 96 |
| CI gates | Rust unit · Clippy · Dart parity |

### Quick health check

```bash
./scripts/build_rust.sh
./scripts/build_rust_mobile.sh all   # iOS + Android before flutter run
cd crates && cargo test --workspace
cd packages/forja_rust && flutter test
cd apps/forja && flutter test integration_test/
```

### Next work (priority order)

1. Step 9 — Dart fallback cleanup ([blockers](./rust-engine-blockers.md))

---

## Step details

Each step below lists: **Rust** (crate status), **App** (wire-up), tests, and file paths. Use the matrix above for the big picture.

---

## Step 0 — Scaffold

**Rust:** ✅ · **App:** ✅

| Item | Path |
|------|------|
| Cargo workspace | `crates/Cargo.toml` |
| FFI crate | `crates/forja-ffi/` |
| Dart loader | `packages/forja_rust/` |
| Build script | `scripts/build_rust.sh` |
| CI | `.github/workflows/rust.yml` |

```bash
cd crates && cargo test -p forja-ffi
cd packages/forja_rust && flutter test test/parity/scaffold_test.dart
```

Wire-up: `ForjaEngine.init()` in `apps/forja/lib/app/bootstrap.dart`.

---

## Step 1 — `forja-utils`

**Rust:** ✅ · **App:** ✅ (5/5 modules wired)

| Module | Rust | App |
|--------|:----:|:---:|
| Episode matcher | ✅ | ✅ |
| Torrent filter | ✅ | ✅ |
| HLS master parse | ✅ | ✅ |
| JS unpacker | ✅ | ✅ |
| KissKH subtitle decrypt | ✅ | ✅ |

| Dart source | Rust module | FFI |
|-------------|-------------|-----|
| `episode_matcher.dart` | `episode_matcher` | `forja_episode_matches` |
| `torrent_filter.dart` | `torrent_filter` | `forja_normalize_torrent_title`, `forja_parse_scene_info_json` |
| `hls_master_parser.dart` | `hls_parser` | `forja_parse_hls_master_json` |
| `unpacker.dart` | `js_unpacker` | `forja_unpack_js` |
| `kisskh_subtitle_decryptor.dart` | `kisskh_subtitle` | `forja_decrypt_kisskh_body` |

```bash
cd crates && cargo test -p forja-utils
cd crates && cargo test -p forja-utils --test golden
cd packages/forja_rust && flutter test test/parity/episode_matcher_test.dart
cd packages/forja_rust && flutter test test/parity/torrent_filter_test.dart
cd packages/forja_rust && flutter test test/parity/hls_test.dart
cd packages/forja_rust && flutter test test/parity/utils_test.dart
```

Fixtures: `crates/forja-utils/tests/fixtures/`

Manual: debrid TV episode pick · HLS quality menu.

Wire-up: `EpisodeMatcherBackend`, `HlsParserBackend` wired in `ForjaEngine.init()` (Rust or Dart reference); `JsUnpackBackend`, `KissKhDecryptBackend`, torrent filter delegate in `rust_delegates.dart`.

---

## Step 2 — `forja-stream-core`

**Rust:** ✅ · **App:** ✅

| Provider | Rust | App |
|----------|:----:|:---:|
| vidlink | ✅ | ✅ |
| vixsrc | ✅ | ✅ |
| vidnest | ✅ | ✅ |
| vidzee | ✅ | ✅ |
| vidrock | ✅ | ✅ |

```bash
cd crates && cargo test -p forja-stream-core
cd packages/forja_rust && flutter test test/parity/stream_providers_test.dart
```

Manual: enable provider in Settings → open movie TMDB 550 → open TV S01E01.

Wire-up: `packages/forja_streaming/lib/src/provider_registry.dart` → `ForjaEngine.buildMovieUrl` / `buildTvUrl`.

---

## Step 3 — `forja-iptv-core`

**Rust:** ✅ · **App:** ✅

| Module | Rust | App |
|--------|:----:|:---:|
| M3U parser | ✅ | ✅ |
| Paste.sh crypto | ✅ | ✅ |
| Xtream EPG base64 | ✅ | ✅ |
| Xtream JSON (categories/streams/series) | ✅ | ✅ |

```bash
cd crates && cargo test -p forja-iptv-core
cd crates && cargo test -p forja-iptv-core --test golden_m3u
cd crates && cargo test -p forja-iptv-core --test golden_xtream
cd packages/forja_rust && flutter test test/parity/m3u_test.dart
cd packages/forja_rust && flutter test test/parity/iptv_test.dart
```

Fixtures: `crates/forja-iptv-core/tests/fixtures/`

Manual: M3U import · CRLF playlist · paste.sh URL · Xtream EPG titles · Xtream portal categories/streams/series episodes.

Wire-up:

- `m3u_parser.dart` → `ForjaEngine.parseM3uChannels`
- `pastesh_decryptor.dart` → `PasteShDecryptorBackend` · fallback `pastesh_decrypt_dart.dart`
- `iptv_network.dart` → `IptvClientBackend` · fallback `iptv_dart_parse.dart`

---

## Step 4 — `forja-stremio-core`

**Rust:** ✅ · **App:** ✅

| Module | Rust | App |
|--------|:----:|:---:|
| Resource URL builder | ✅ | ✅ |
| Addon URL split | ✅ | ✅ |
| Manifest URL normalize | ✅ | ✅ |
| Manifest JSON parse | ✅ | ✅ |
| Streams/subtitles JSON parse | ✅ | ✅ |
| Catalog/meta JSON parse | ✅ | ✅ |
| HTTP GET (catalog/meta/stream/manifest) | ✅ | ✅ |

```bash
cd crates && cargo test -p forja-stremio-core
cd packages/forja_rust && flutter test test/parity/stremio_test.dart
```

Manual: install addon → Home catalog rows → player next-episode via `stremio_direct`.

No Stremio nav tab — catalogs on Home + `StremioCatalogScreen`.

Wire-up: `StremioServiceBackend` in `stremio_service.dart`.

---

## Step 5 — `forja-webstreamr`

**Rust:** ✅ · **App:** ✅ (23/23 extractors · 21/21 sources; fetch/registry stays Dart)

| Extractor | Rust | App |
|-----------|:----:|:---:|
| vidsrc (3-page chain) | ✅ | ✅ |
| streamembed | ✅ | ✅ |
| savefiles | ✅ | ✅ |
| dropload | ✅ | ✅ |
| supervideo | ✅ | ✅ |
| vidora | ✅ | ✅ |
| fsst | ✅ | ✅ |
| vixsrc | ✅ | ✅ |
| kinoger (AES body) | ✅ | ✅ |
| youtube | ✅ | ✅ |
| filemoon (iframe hop) | ✅ | ✅ |
| hubdrive (HubCloud link) | ✅ | ✅ |
| hubcloud (multi-link) | ✅ | ✅ |
| rgshows (JSON body) | ✅ | ✅ |
| external (passthrough) | ✅ | ✅ |
| mixdrop (MFP redirect) | ✅ | ✅ |
| streamtape (MFP redirect) | ✅ | ✅ |
| uqload (MFP redirect) | ✅ | ✅ |
| doodstream (MFP redirect) | ✅ | ✅ |
| filelions (MFP stream) | ✅ | ✅ |
| lulustream (MFP stream) | ✅ | ✅ |
| fastream (MFP stream) | ✅ | ✅ |
| voe (MFP stream + redirect) | ✅ | ✅ |

FFI: `forja_extract_embed_html_json`, `forja_extract_vidsrc_chain_json`, `forja_extract_hubcloud_links_json`, `forja_extract_mfp_embed_html_json`, `forja_resolve_webstreamr_source_json`, `forja_extract_kinoger_episode_urls_json`, `forja_parse_webstreamr_source_html_json`. MFP stream fetch runs in Rust (blocking HTTP). Page fetch + registry still Dart.

**Sources (URL-only / parse helpers):**

| Source | Rust | App |
|--------|:----:|:---:|
| vidsrc (embed URL) | ✅ | ✅ |
| vixsrc (embed URL) | ✅ | ✅ |
| rgshows (API URL) | ✅ | ✅ |
| kinoger (show.js episode URLs) | ✅ | ✅ |
| meinecloud (HTML `[data-link]`) | ✅ | ✅ |
| verhdlink (HTML `._player-mirrors`) | ✅ | ✅ |
| megakino (HTML `.video-inside iframe`) | ✅ | ✅ |
| homecine (HTML `.les-content a` iframe) | ✅ | ✅ |
| mostraguarda (HTML `[data-link]`) | ✅ | ✅ |
| eurostreaming (HTML episode mirrors) | ✅ | ✅ |
| cinehdplus (HTML episode mirrors + lang) | ✅ | ✅ |
| streamkiste (HTML episode mirrors) | ✅ | ✅ |
| frenchcloud (HTML `[data-link]`) | ✅ | ✅ |
| cuevana (HTML `.open_submenu`) | ✅ | ✅ |
| hdhub4u (HTML hubdrive links) | ✅ | ✅ |
| einschalten (JSON watch API) | ✅ | ✅ |
| movix (JSON player_links) | ✅ | ✅ |
| frembed (JSON link* keys) | ✅ | ✅ |
| kokoshka (HTML dooplayer + JSON embed) | ✅ | ✅ |
| 4khdhub (HTML download items) | ✅ | ✅ |
| vegamovies (HTML nexdrive vcloud) | ✅ | ✅ |

```bash
cd crates && cargo test -p forja-webstreamr
cd crates && cargo test -p forja-webstreamr --test golden_extractors
cd crates && cargo test -p forja-webstreamr --test golden_sources
cd packages/forja_rust && flutter test test/parity/webstreamr_test.dart
cd packages/forja_rust && flutter test test/parity/webstreamr_sources_test.dart
```

Fixtures: `crates/forja-webstreamr/tests/fixtures/`

Manual: WebStreamr with Rust on — streams from hosts above use Rust HTML parse.

Wire-up: `WebstreamrParseBackend` · `tryRustExtractFromHtml` / `tryRustVidsrcChain` / `tryRustResolveSource` / `tryRustKinogerEpisodeUrls` / `tryRustParseSourceHtml` · `rust_delegates.dart`.

---

## Step 6 — `forja-scrapers`

**Rust:** ✅ · **App:** ✅ (parse only; HTTP stays Dart)

| Scraper | Rust | App |
|---------|:----:|:---:|
| Knaben | ✅ | ✅ |
| ThePirateBay | ✅ | ✅ |
| Uindex | ✅ | ✅ |
| Dedup by infohash | ✅ | ✅ |

```bash
cd crates && cargo test -p forja-scrapers
cd packages/forja_rust && flutter test test/parity/scrapers_test.dart
```

Manual: torrent search on movie/TV details · no duplicate magnets.

Wire-up: `ScraperParseBackend` in `forja_scrapers`.

---

## Step 7 — `forja-torrent` + `forja-proxy`

**Rust:** ✅ · **App:** ✅ (with Dart fallbacks)

| Component | Rust | App |
|-----------|:----:|:---:|
| Torrent playback | ✅ librqbit + axum stream | ✅ `TorrentStreamService` prefers Rust |
| `/proxy?url=` + Range | axum streaming | ✅ forwards to Rust when engine on |
| `/hls-proxy` | — | Dart shelf (m3u8 rewrite + PNG strip) |
| libtorrent fallback | — | when Rust engine off or start fails |

```bash
cd crates && cargo test -p forja-torrent
cd crates && cargo test -p forja-proxy
cd packages/forja_rust && flutter test test/parity/torrent_stub_test.dart
cd packages/forja_rust && flutter test test/parity/proxy_test.dart
```

FFI: `forja_torrent_engine_start`, `forja_torrent_stream_json`, `forja_torrent_status_json`.

Wire-up: `TorrentEngineBackend` in `rust_delegates.dart` · `TorrentStreamService` · `LocalServerService` proxy forward.

---

## Step 8 — Flutter integration

**Rust:** N/A · **App:** N/A

| Task | Status |
|------|--------|
| `ForjaEngine.init()` in bootstrap | ✅ |
| Rust engine status (Developer, all platforms) | ✅ |
| M3U / paste.sh / Xtream (EPG + JSON) → Rust | ✅ |
| Provider URLs → Rust (5 providers) | ✅ |
| Episode matcher + HLS delegates | ✅ |
| Dylib bundled in `.app` | ✅ |

WebView extractors stay in the app (`stream_extractor_view.dart` + `InAppWebView`) — out of scope per RFC-009. No `forja_adapters/` package required for this migration.

```bash
./scripts/build_rust.sh
cd packages/forja_rust && flutter test
```

| Test file | Covers |
|-----------|--------|
| `scaffold_test.dart` | FFI add, version |
| `episode_matcher_test.dart` | 10 golden cases Rust↔Dart |
| `stream_providers_test.dart` | vidlink, vixsrc, vidnest URLs |
| `m3u_test.dart` | M3U golden fixtures (4/4) |
| `iptv_test.dart` | Xtream decode, categories/streams/series, paste.sh |
| `webstreamr_test.dart` | 21/23 extractors via FFI |
| `webstreamr_sources_test.dart` | 22/22 sources via FFI |
| `stremio_test.dart` | resource URL builder + HTTP + JSON parse |
| `hls_test.dart` | master playlist parse |
| `torrent_filter_test.dart` | normalize + scene info |
| `scrapers_test.dart` | Knaben HTML |
| `torrent_stub_test.dart` | librqbit session + status JSON |

Manual: boot log shows `Rust engine v0.1.0` · IPTV + debrid + VidLink smoke test.

**Settings → Developer:** live Rust engine status (loaded / fallback).

### Troubleshooting dylib load

If you see `Rust library not loaded — Dart fallback`:

```bash
FORJA_RUST_LIB="$(pwd)/crates/target/release/libforja_ffi.dylib" flutter run -d macos
# or
./scripts/build_rust.sh && flutter run -d macos
```

---

## Step 9 — Cleanup

**Rust:** N/A · **App:** N/A · **Dart removed:** partial (9/11 items)

**Goal:** Remove duplicate Dart engine code. Fallbacks live in one place (`reference/`) until every platform bundles Rust — then delete. Blockers → [rust-engine-blockers.md](./rust-engine-blockers.md).

### Consolidation (done)

| Item | Status | Path |
|------|:----:|------|
| M3U parser fallback | ✅ | `packages/forja_rust/lib/src/reference/m3u_dart_parser.dart` |
| IPTV Xtream + series episodes | ✅ | `reference/iptv_dart_parse.dart` |
| Paste.sh decrypt | ✅ | `reference/pastesh_decrypt_dart.dart` |
| Episode matcher | ✅ | `reference/episode_matcher_dart.dart` |
| HLS master parse | ✅ | `reference/hls_dart_parse.dart` |
| JS unpacker | ✅ | `reference/js_unpacker_dart.dart` |
| KissKH subtitle decrypt | ✅ | `reference/kisskh_decrypt_dart.dart` |
| Torrent filter | ✅ | `reference/torrent_filter_dart.dart` |
| Stremio JSON + URL helpers | ✅ | `reference/stremio_dart_parse.dart` |
| Scrapers HTML parse + dedup | ✅ | `reference/scrapers_dart_parse.dart` |
| Provider URL templates | ✅ | `packages/forja_streaming/lib/src/provider_fallback_urls.dart` |
| Magnet player torrent API | ✅ | `TorrentStreamService.listTorrentFiles` (no direct libtorrent in UI) |

### Dead code removed (done)

| Removed | Was duplicate of |
|---------|------------------|
| `forja_streaming/.../hls_master_parser.dart` | `forja_core` / Rust FFI |
| `forja_streaming/.../debrid_api.dart` | `forja_api` |

### Deletion (open)

| Item | Status | Blocker |
|------|:----:|---------|
| Delete `reference/*.dart` (10 files) | ❌ | B1 · B3 · B6 — need Rust on all platforms + parity |
| Drop `libtorrent_flutter` from pubspecs | ❌ | B2 · B4 — mobile torrent today; desktop fallback |
| librqbit in mobile Rust FFI | ❌ | B2 · B7 |
| Golden fixture per webstreamr extractor | ✅ | B5 — 23/23 Rust · 21/23 Dart (lulustream/fastream Rust-only) |
| App `integration_test/` smoke | ✅ | B4 — 7 tests in CI |

### Reference layer inventory

All under `packages/forja_rust/lib/src/reference/` — **kept for internal fallback + parity tests**, not deleted yet.

| File | Step | Imported from (production) |
|------|------|----------------------------|
| `m3u_dart_parser.dart` | 3 | `ForjaEngine` facade |
| `iptv_dart_parse.dart` | 3 | `iptv_network.dart` |
| `pastesh_decrypt_dart.dart` | 3 | `pastesh_decryptor.dart` |
| `episode_matcher_dart.dart` | 1 | `ForjaEngine` facade |
| `hls_dart_parse.dart` | 1 | `ForjaEngine` facade |
| `js_unpacker_dart.dart` | 1 | `unpacker.dart` via delegate |
| `kisskh_decrypt_dart.dart` | 1 | `kisskh_subtitle_decryptor.dart` |
| `torrent_filter_dart.dart` | 1 | `torrent_filter.dart` |
| `stremio_dart_parse.dart` | 4 | `stremio_service.dart` |
| `scrapers_dart_parse.dart` | 6 | `knaben` · `tpb` · `uindex` scrapers |

### What stays (not Step 9 targets)

- Webstreamr fetcher / registry / page HTTP (orchestration)
- Scrapers search HTTP
- HLS `/hls-proxy` (shelf rewrite)
- WebView extractors (`stream_extractor_view.dart`)
- `libtorrent_flutter` on mobile until B2/B7 close

```bash
# Parity gates before deleting any reference file
cd packages/forja_rust && flutter test
cd crates && cargo test -p forja-webstreamr --test golden_extractors
```

Manual: boot log `Rust engine v0.1.0` on desktop + mobile after `build_rust_mobile.sh` · IPTV import · magnet play · one VidLink stream.

---

## CI matrix

| Job | Command | Gate |
|-----|---------|------|
| Rust unit | `cargo test --workspace` | required |
| Clippy | `cargo clippy --workspace` | required |
| Dart parity | `cd packages/forja_rust && flutter test` | required |
| App integration | `cd apps/forja && flutter test integration_test/` | required (macOS CI) |

---

## Updating this doc

After completing work:

1. Update the **feature matrix** — must match step detail tables (see doc status rules in `.cursor/rules/rust-migration.mdc`).
2. Update the step detail section.
3. Update [RFC-009](../rfc/009-rust-ffi.md) acceptance checkboxes if applicable.
4. Run health check commands; note pass/fail in PR.

See `.cursor/rules/rust-migration.mdc` for agent instructions.
