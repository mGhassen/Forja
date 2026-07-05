# Rust engine migration — progress tracker

**Last updated:** 2026-07-05  
**Branch:** `feat/rust-migratiom` (typo in branch name)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)  
**Plan:** `.cursor/plans/rust_kotlin_migration_*.plan.md` (local, not versioned)

---

## Status at a glance

**Goal:** move heavy logic from Dart → Rust. Flutter stays the UI. Old Dart code stays as fallback until each piece is proven, then deleted (Step 9).

**Where we are:** Rust infrastructure is mostly built. About half of user-facing features call Rust at runtime. Nothing has been deleted from Dart yet.

### Three columns — read every table this way

| Column | Question |
|--------|----------|
| **Rust** | Code exists in `crates/` + exposed via FFI? |
| **App** | Running app calls Rust when `use_rust_engine` is on? |
| **Dart removed** | Old duplicate deleted? (always **no** until Step 9) |

Rust can be **yes** while App is **no** — code exists but the app still uses Dart.

### Migration phases

| Phase | What | Status |
|-------|------|--------|
| **A** | Rust crates in `crates/` | mostly done |
| **B** | Dart FFI bridge `packages/forja_rust/` + parity tests | partial |
| **C** | Flutter call sites wired in the app | partial |
| **D** | Delete Dart duplicates | not started |

### Feature matrix

| Area | Rust | App | Notes |
|------|:----:|:---:|-------|
| **0 — Scaffold** (build, FFI, CI) | ✅ | ✅ | `ForjaEngine.init()`, dylib bundling |
| **1 — Utils** (episode match, HLS, torrent filter) | ✅ | ✅ | JS unpacker + KissKH decrypt: Rust only, not wired |
| **2 — Stream URLs** | 3/5 | 3/5 | ✅ vidlink, vixsrc, vidnest · ❌ vidzee, vidrock |
| **3 — IPTV** | 4/4 | 4/4 | M3U, paste.sh, EPG decode, Xtream JSON parse |
| **4 — Stremio** | partial | partial | ✅ URL helpers · ❌ HTTP, manifest parse, catalogs |
| **5 — Webstreamr** | 24/49 extractors · 7/22 sources | partial | extractors + URL/HTML sources wired |
| **6 — Scrapers** | ✅ | ✅ | HTML parse + dedup; HTTP fetch stays Dart |
| **7 — Torrent + proxy** | stubs | ❌ | still `libtorrent_flutter` + Dart shelf |
| **8 — Flutter integration** | — | partial | toggle in Settings → Developer |
| **9 — Cleanup** | — | ❌ | delete Dart fallbacks |

### What runs in Rust today

When boot log shows `[ForjaEngine] Rust engine v0.1.0`:

- IPTV: M3U parse, paste.sh decrypt, Xtream EPG decode, Xtream categories/streams JSON
- Streaming: embed URLs for VidLink, VixSrc, Vidnest
- Utils: episode file matching, HLS master parse, torrent title filter
- Stremio: URL building only (not catalog browsing)
- Scrapers: Knaben / TPB / Uindex HTML parse + dedup
- Webstreamr: 23 extractors + 7 sources (vidsrc/vixsrc/rgshows embed URLs, kinoger show.js, meinecloud/verhdlink/megakino HTML parse)

### Still 100% Dart

- Stremio catalog / meta / stream HTTP
- Webstreamr: HTML-scrape sources (homecine, movix, frembed, etc.), fetcher, registry
- Torrent session + local stream proxy
- Vidzee / Vidrock provider URLs

### Numbers

| Metric | Value |
|--------|-------|
| Rust crates | 9 (8 domain + `forja-ffi`) |
| Stream providers wired | 3 / 5 |
| Webstreamr extractors ported | 24 / 49 |
| Webstreamr URL sources ported | 7 / 22 |
| Dart parity tests | 40 |
| CI gates | Rust unit · Clippy · Dart parity |

### Quick health check

```bash
./scripts/build_rust.sh
cd crates && cargo test --workspace
cd packages/forja_rust && flutter test
```

### Next work (priority order)

1. Port more HTML-scrape webstreamr sources (homecine, movix, frembed, …)
2. Real libtorrent in `forja-torrent`
3. Stremio HTTP / manifest parse through FFI

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

**Rust:** ✅ · **App:** partial (3/5 modules wired)

| Module | Rust | App |
|--------|:----:|:---:|
| Episode matcher | ✅ | ✅ |
| Torrent filter | ✅ | ✅ |
| HLS master parse | ✅ | ✅ |
| JS unpacker | ✅ | ❌ |
| KissKH subtitle decrypt | ✅ | ❌ |

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
```

Fixtures: `crates/forja-utils/tests/fixtures/`

Manual: debrid TV episode pick · HLS quality menu.

Wire-up: `EpisodeMatcherBackend`, `HlsParserBackend`, torrent filter delegate in `rust_delegates.dart`.

---

## Step 2 — `forja-stream-core`

**Rust:** 3/5 · **App:** 3/5

| Provider | Rust | App |
|----------|:----:|:---:|
| vidlink | ✅ | ✅ |
| vixsrc | ✅ | ✅ |
| vidnest | ✅ | ✅ |
| vidzee | ❌ | Dart |
| vidrock | ❌ | Dart |

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
| Xtream JSON (categories/streams) | ✅ | ✅ |

```bash
cd crates && cargo test -p forja-iptv-core
cd crates && cargo test -p forja-iptv-core --test golden_m3u
cd crates && cargo test -p forja-iptv-core --test golden_xtream
cd packages/forja_rust && flutter test test/parity/m3u_test.dart
cd packages/forja_rust && flutter test test/parity/iptv_test.dart
```

Fixtures: `crates/forja-iptv-core/tests/fixtures/`

Manual: M3U import · CRLF playlist · paste.sh URL · Xtream EPG titles · Xtream portal categories/streams.

Wire-up:

- `m3u_parser.dart` → `ForjaEngine.parseM3uChannels`
- `pastesh_decryptor.dart` → `PasteShDecryptorBackend`
- `iptv_network.dart` → `IptvClientBackend` (decodeXtreamText, parseCategoriesJson, parseStreamsJson)

---

## Step 4 — `forja-stremio-core`

**Rust:** partial · **App:** partial (URL helpers only)

| Module | Rust | App |
|--------|:----:|:---:|
| Resource URL builder | ✅ | ✅ |
| Addon URL split | ✅ | ✅ |
| Manifest URL normalize | ✅ | ✅ |
| Manifest JSON parse | ✅ | ❌ |
| Catalog / meta / stream fetch | ❌ | Dart HTTP |

```bash
cd crates && cargo test -p forja-stremio-core
cd packages/forja_rust && flutter test test/parity/stremio_test.dart
```

Manual: install addon → Home catalog rows → player next-episode via `stremio_direct`.

No Stremio nav tab — catalogs on Home + `StremioCatalogScreen`.

Wire-up: `StremioServiceBackend` in `stremio_service.dart`.

---

## Step 5 — `forja-webstreamr`

**Rust:** 24/49 · **App:** partial (23 extractors wired via `WebstreamrParseBackend`)

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

**Rust:** stubs · **App:** ❌

| Component | Rust | App |
|-----------|:----:|:---:|
| Torrent session | stub | `libtorrent_flutter` |
| Local proxy | axum skeleton | Dart shelf |

```bash
cd crates && cargo test -p forja-torrent
cd crates && cargo test -p forja-proxy
cd packages/forja_rust && flutter test test/parity/torrent_stub_test.dart
```

Blocked on libtorrent crate integration.

---

## Step 8 — Flutter integration

**App:** partial

| Task | Status |
|------|--------|
| `ForjaEngine.init()` in bootstrap | ✅ |
| `use_rust_engine` setting + Developer UI toggle | ✅ |
| M3U / paste.sh / Xtream EPG → Rust | ✅ |
| Provider URLs → Rust (3 providers) | ✅ |
| Episode matcher + HLS delegates | ✅ |
| Dylib bundled in `.app` | ✅ |
| `forja_adapters/` WebView package | ❌ |

```bash
./scripts/build_rust.sh
cd packages/forja_rust && flutter test
```

| Test file | Covers |
|-----------|--------|
| `scaffold_test.dart` | FFI add, version |
| `episode_matcher_test.dart` | 10 golden cases Rust↔Dart |
| `stream_providers_test.dart` | vidlink, vixsrc, vidnest URLs |
| `m3u_test.dart` | M3U golden fixtures |
| `iptv_test.dart` | Xtream decode + paste.sh |
| `stremio_test.dart` | resource URL builder |
| `hls_test.dart` | master playlist parse |
| `torrent_filter_test.dart` | normalize + scene info |
| `scrapers_test.dart` | Knaben HTML |
| `torrent_stub_test.dart` | torrent session stub |

Manual: boot log shows `Rust engine v0.1.0` · toggle off → Dart fallback works · IPTV + debrid + VidLink smoke test.

**Settings → Developer:** live Rust status + toggle (restart required).

### Troubleshooting dylib load

If you see `Rust library not loaded — Dart fallback`:

```bash
FORJA_RUST_LIB="$(pwd)/crates/target/release/libforja_ffi.dylib" flutter run -d macos
# or
./scripts/build_rust.sh && flutter run -d macos
```

---

## Step 9 — Cleanup

**Not started.** Delete Dart duplicates only after Rust path is proven stable.

- [ ] Delete Dart M3U parser body
- [ ] Remove Dart provider URL lambdas behind flag
- [ ] Port remaining webstreamr extractors
- [ ] Wire torrent + full Stremio HTTP
- [ ] Golden fixtures for every extractor

---

## CI matrix

| Job | Command | Gate |
|-----|---------|------|
| Rust unit | `cargo test --workspace` | required |
| Clippy | `cargo clippy --workspace` | required |
| Dart parity | `cd packages/forja_rust && flutter test` | required |
| App integration | manual / future `integration_test/` | optional |

---

## Updating this doc

After completing work:

1. Update the **feature matrix** at the top (Rust / App columns).
2. Update the step detail section.
3. Update [RFC-009](../rfc/009-rust-ffi.md) acceptance checkboxes.
4. Run health check commands; note pass/fail in PR.

See `.cursor/rules/rust-migration.mdc` for agent instructions.
