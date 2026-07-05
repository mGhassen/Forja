# Phase 1 — Rust engine

**Status:** Complete (2026-07-05)
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)
**Next phase:** [Phase 2 — Rust engine complete](./02-rust-engine-complete.md)
**Migration index:** [README.md](./README.md)

---


## Status at a glance

**Goal:** Rust parsers + FFI in production on every native platform. No runtime Dart engine fallback.

| | |
|--|--|
| **Progress** | **100% — Phase complete** |
| **Deferred to Phase 2** | B2 mobile librqbit · drop libtorrent on mobile |

**Legend:** ✅ done · 🔄 started · ⬜ todo

### Task tracker

#### ✅ Steps 0 → 9 — all done

| Step | What | |
|------|------|---|
| 0 | Scaffold — build scripts, FFI, CI | ✅ |
| 1 | Utils — episode match, HLS, torrent filter, JS unpack, KissKH | ✅ |
| 2 | Stream URLs — 5 template providers | ✅ |
| 3 | IPTV — M3U, paste.sh, Xtream parse | ✅ |
| 4 | Stremio — URL + JSON + HTTP | ✅ |
| 5 | Webstreamr — 23 extractors, 21 sources (parse in Rust) | ✅ |
| 6 | Scrapers — knaben/tpb/uindex parse + dedup | ✅ |
| 7 | Torrent + proxy — librqbit desktop, local proxy | ✅ |
| 8 | Flutter integration — `ForjaEngine.init()`, delegates, dylib | ✅ |
| 9 | Cleanup — runtime Dart engine removed | ✅ |

#### Handed off to Phase 2

| What | Phase 2 task |
|------|--------------|
| Mobile librqbit compile + magnet play | P2-10 → P2-14 |
| Remove `libtorrent_flutter` | P2-20 → P2-23 |
| Move fetch/route pipelines into Rust | P2-80 → P2-87 |

### Delivered (counts)

| Item | Count |
|------|------:|
| Rust crates | 9 |
| Stream providers wired | 5 / 5 |
| Webstreamr extractors | 23 / 23 |
| Webstreamr sources | 21 / 21 |
| Dart parity tests | 96 |

### Quick health check

```bash
./scripts/build_rust.sh
./scripts/build_rust_mobile.sh all
cd crates && cargo test --workspace
cd packages/forja_rust && flutter test
```

**Next:** [Phase 2 — Rust engine complete](./02-rust-engine-complete.md)

---


## Blockers

**Retrospective.** Phase 1 complete; B2 + libtorrent drop → Phase 2.

## Overview

| Status | Count | IDs |
|--------|------:|-----|
| Phase 2 (engine complete) | 1 | B2 |
| Done / by design | 8 | B1 · B3 · B4 · B5 · B6 · B7 · B8 · B9 |

**Step 9 unlock:** 2 / 3 items done (see [Step 9 map](#step-9--open-work-mapped-to-blockers)).

| Metric | Done | Target |
|--------|-----:|-------:|
| Runtime Dart engine files in `lib/` | 0 | 0 |
| Parity baseline files in `test/` | 10 | 10 |
| `libtorrent_flutter` pubspec deps | 0 | 3 removed |
| Webstreamr extractor goldens | 23 | 23 |
| Webstreamr source goldens | 21 | 21 |
| M3U fixtures in Dart parity | 4 | 4 |
| Dart parity test files | 14 | 14 |
| Dart parity tests | 96 | — |
| App integration tests | 1 smoke file / 11 tests | boot · M3U · IPTV · stream · torrent · Stremio · scrapers · episode match |

---

## At a glance

| ID | Blocker | Severity | Progress | Blocks |
|----|---------|----------|----------|--------|
| B1 | Runtime Dart engine fallback | **high** | done | — |
| B2 | `libtorrent_flutter` on mobile (+ desktop fallback) | **medium** | blocked (upstream) | Drop libtorrent from pubspecs |
| B3 | Dart engine layer in `lib/` | **high** | done | — |
| B4 | App `integration_test/` | **medium** | done (core) | Optional UI E2E · magnet→play |
| B5 | Webstreamr golden fixtures | **medium** | done | Optional filelions/voe stream-path goldens |
| B6 | RFC-009 parity gaps | **medium** | done | lulustream/fastream stream-fetch (documented) |
| B7 | Mobile Rust FFI packaging | **high** | done (parsers) | librqbit mobile (B2) |
| B8 | Dylib load / dev ergonomics | **low** | done | Optional full-app CI artifact job |
| B9 | RFC-009 sync | **low** | done | Update RFC status when Step 9 completes |

**Not blockers** (by design): WebView extractors · webstreamr fetcher/registry · scraper HTTP · HLS `/hls-proxy` · WASM (v3.0).

---

## Dependency chain

```
B2 libtorrent on mobile
 └── blocks dropping libtorrent_flutter from pubspecs (Step 9)

Release builds bundle Rust parsers (B7 done)
 └── debug without build_rust_mobile.sh → engine unavailable (expected)
```

**B2 unlock:** [Phase 2 P2-10](./02-rust-engine-complete.md#b2--mobile-librqbit-critical-path) — mobile magnet via Rust FFI before Flutter delete.

---

## Blocker details

### B1 — Runtime Dart engine fallback

**Progress:** done — removed `installDartFallbackDelegates()`; Rust required for parsers

| Done | Todo |
|------|------|
| [x] Rust always loaded at boot (`ForjaEngine.init()`) | |
| [x] Developer toggle removed | |
| [x] All domain delegates when dylib loads | |
| [x] Removed runtime Dart fallback from bootstrap | |
| [x] `FORJA_RUST_STRICT=1` fails fast when dylib missing (desktop debug) | |

### B7 — Mobile Rust FFI packaging

**Progress:** done (parser engine) — librqbit mobile tracked under B2

| Done | Todo |
|------|------|
| [x] `forja-ffi` feature flags (`torrent-engine`, `local-proxy`) | [ ] librqbit on mobile (B2; libtorrent = same user feature) |
| [x] `scripts/build_rust_mobile.sh` + NDK discovery | [x] Android/iOS quickstart in `crates/README.md` + `apps/forja/README.md` |
| [x] Android CI (`android-ffi` job) + iOS CI (`ios-ffi` job) | |
| [x] `forjaBuildRust=true` — release APK bundles `.so` via `preReleaseBuild` | |
| [x] iOS `build_rust_ios.sh` — compiles on Release/Profile Xcode builds | |
| [x] Gradle `FORJA_BUILD_RUST_ANDROID=1` for debug APK with Rust | |
| [x] iOS Xcode copy phase + Android jniLibs path | |
| [x] Boot tries Rust on all platforms | |

| | |
|--|--|
| **What** | Mobile must load the same Rust parser engine as desktop |
| **Why it blocks** | Platform parity — release APK/IPA bundle `.so`/`.dylib` |
| **Files** | `scripts/build_rust_mobile.sh` · `library_path.dart` · `facade.dart` · `android/.../jniLibs/` · `ios/Runner/Frameworks/` |
| **Manage** | Mobile FFI ships parsers + webstreamr; torrent stays libtorrent until librqbit compiles on iOS/Android |
| **Unblocks** | Single engine path for IPTV/Stremio/scrapers on all native platforms |

---

### B2 — `libtorrent_flutter` dependency

**Progress:** blocked on upstream — iOS compile fails; libtorrent preserved on mobile

| Done | Todo |
|------|------|
| [x] Desktop: `TorrentStreamService` prefers Rust/librqbit | [ ] librqbit in mobile Rust FFI |
| [x] Mobile: libtorrent = torrent engine (feature preserved) | [ ] Upstream: `librqbit-dualstack-sockets` iOS `bind_device` |
| [x] Magnet player via `TorrentStreamService` | [ ] Port `applyConnectionsLimit` to librqbit session |
| [x] FFI torrent stubs on mobile build (`--no-default-features`) | |
| [x] CI probe: `mobile-torrent-probe` + `android-torrent-probe` (informational) | |
| [x] `scripts/try_build_mobile_torrent.sh` | |

| | |
|--|--|
| **What** | Native torrent engine still linked in `apps/forja`, `forja_streaming`, `forja_api` |
| **Why it blocks** | Mobile `--features torrent-engine` fails to compile (see below); desktop falls back to libtorrent when Rust port is 0 |
| **iOS compile error** | `librqbit-dualstack-sockets 0.7.0` → `Socket::bind_device` not available on iOS |
| **Probe** | `./scripts/try_build_mobile_torrent.sh ios` |
| **Files** | `packages/forja_streaming/lib/src/torrent_stream_service.dart` · `crates/forja-torrent/` |
| **Manage** | Keep libtorrent on mobile; re-run probe when bumping librqbit; optional fork/patch of dualstack-sockets |
| **Unblocks** | Step 9 “Drop libtorrent_flutter”; single torrent engine on all platforms |

---

### B3 — Dart engine layer in `lib/`

**Progress:** done — baselines moved to `test/parity/dart_baseline/`

| Done | Todo |
|------|------|
| [x] Removed `lib/src/dart_fallback/` (10 files) | |
| [x] Parity baselines in `test/parity/dart_baseline/` | |
| [x] Production uses `*Backend` hooks only (Rust via delegates) | |
| [x] `melos run rust:release-check` for mobile artifacts | |

| | |
|--|--|
| **What** | No duplicate Dart engine in shipped app; test baselines compare Rust output |
| **Files** | `test/parity/dart_baseline/*.dart` · `test/helpers/parity_backends.dart` |
| **Unblocks** | Step 9 “delete Dart duplicates” for production |

---

### B4 — App integration tests

**Progress:** done (core engine smoke) — optional UI E2E remains

| Done | Todo |
|------|------|
| [x] Rust unit + Clippy in CI | [ ] Full UI boot smoke (optional) |
| [x] Dart parity 14 files / 96 tests in CI | [ ] Smoke: magnet → play end-to-end |
| [x] `apps/forja/integration_test/engine_smoke_test.dart` (11 tests) | |
| [x] Smoke: `ForjaEngine` + delegates (IPTV · Stremio · scrapers) | |
| [x] Smoke: M3U · stream URL · torrent loopback | |
| [x] CI job in `rust.yml` + `melos run rust:integration` | |

---

### B5 — Webstreamr golden fixtures

**Progress:** done — 23/23 extractors · 21/21 sources · Dart parity 21/23

---

### B6 — RFC-009 parity gaps

**Progress:** done — lulustream/fastream stream-fetch documented as Rust-only

---

### B8 — Dylib load / dev ergonomics

**Progress:** done

---

### B9 — RFC-009 sync

**Progress:** done

---

## Step 9 — open work mapped to blockers

| Step 9 item | Blocker(s) | Progress |
|-------------|------------|----------|
| Drop `libtorrent_flutter` | B2 | open |
| Golden fixtures for every extractor | B5 | done |
| App `integration_test/` smoke | B4 | done (core) |
| Delete runtime Dart engine from `lib/` | B1 · B3 | done |

---

## Explicit non-blockers

Do **not** track these as migration blockers:

| Item | Reason |
|------|--------|
| `forja_adapters/` WebView package | Never existed; WebView stays in app per RFC-009 |
| Webstreamr fetcher / registry / page HTTP | Orchestration stays Dart (same as scraper HTTP) |
| HLS `/hls-proxy` | Out of Rust scope; shelf rewrite in Dart |
| WASM / web client | RFC-014 v3.0 |
| KMP / Compose | [Phase 3](./03-kotlin-compose.md) |
| Parity baselines in `test/parity/dart_baseline/` | Test-only; not shipped |

**Known intentional gaps (not bugs):**

- `lulustream` / `fastream` — MFP stream URL fetch is Rust golden + wiremock only
- Webstreamr page fetch + registry stay in Dart by design (RFC-009).

---

## Quick reference

| Blocker | Manage by |
|---------|-----------|
| B2 libtorrent | Keep until librqbit mobile or explicit product decision |
| B4 optional E2E | Add when magnet→play regression needed |
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

Wire-up: `ForjaEngine.init()` + `installRustAppDelegates()` — Rust required; `FORJA_RUST_STRICT=1` fails fast in debug when dylib missing.

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
| `episode_matcher_test.dart` | 18 golden debrid filename cases Rust↔Dart |
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

Debug desktop builds also print a `[Boot] Rust engine NOT loaded` warning. Set `FORJA_RUST_STRICT=1` to fail fast when the dylib is missing.

---

## Step 9 — Cleanup

**Rust:** N/A · **App:** N/A · **Dart removed:** runtime engine yes (10 files → test baselines)

**Goal:** Rust-only engine in production. Dart baselines kept for parity tests only (`test/parity/dart_baseline/`).

### Consolidation (done)

| Item | Status | Path |
|------|:----:|------|
| M3U parser | ✅ | Rust FFI only (`ForjaEngine.parseM3uChannels`) |
| IPTV Xtream + series episodes | ✅ | Rust via `IptvClientBackend` |
| Paste.sh decrypt | ✅ | Rust via `PasteShDecryptorBackend` |
| Episode matcher | ✅ | Rust via `EpisodeMatcherBackend` |
| HLS master parse | ✅ | Rust via `HlsParserBackend` |
| JS unpacker | ✅ | Rust via `JsUnpackBackend` |
| KissKH subtitle decrypt | ✅ | Rust via `KissKhDecryptBackend` |
| Torrent filter | ✅ | Rust via `TorrentFilterBackend` |
| Stremio JSON + URL helpers | ✅ | Rust via `StremioServiceBackend` |
| Scrapers HTML parse + dedup | ✅ | Rust via `ScraperParseBackend` |
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
| Delete runtime Dart engine from `lib/` | ✅ | B1 · B3 — moved to `test/parity/dart_baseline/` |
| Drop `libtorrent_flutter` from pubspecs | ❌ | B2 |
| Mobile Rust in release APK/IPA | ✅ | B7 — `forjaBuildRust=true` · iOS Release phase |
| librqbit in mobile Rust FFI | ❌ | B2 |
| Golden fixture per webstreamr extractor | ✅ | B5 — 23/23 Rust · 21/23 Dart (lulustream/fastream Rust-only) |
| App `integration_test/` smoke | ✅ | B4 — 11 tests in CI |

### Parity baselines (test-only)

`packages/forja_rust/test/parity/dart_baseline/` — **not shipped**; used by `flutter test` to compare Rust FFI output.

Barrel: `test/parity/dart_baseline/dart_baseline.dart`

```bash
melos run rust:test
melos run rust:release-check   # after build_rust_mobile.sh
```

### What stays (not Step 9 targets)

- Webstreamr fetcher / registry / page HTTP (orchestration)
- Scrapers search HTTP
- HLS `/hls-proxy` (shelf rewrite)
- WebView extractors (`stream_extractor_view.dart`)
- `libtorrent_flutter` on mobile until B2 (librqbit mobile FFI)
- Parity baselines in `test/parity/dart_baseline/` (test-only)

Manual: boot log `Rust engine v0.1.0` on desktop + mobile after `build_rust_mobile.sh` · IPTV import · magnet play · one VidLink stream.

---

## CI matrix

| Job | Command | Gate |
|-----|---------|------|
| Rust unit | `cargo test --workspace` | required |
| Clippy | `cargo clippy --workspace` | required |
| Dart parity | `cd packages/forja_rust && flutter test` | required |
| App integration | `melos run rust:integration` | required (macOS CI) |
| Android FFI | `./scripts/build_rust_mobile.sh android` | required |
| iOS FFI | `./scripts/build_rust_mobile.sh ios` | required |
| Mobile artifact check | `melos run rust:release-check` | local / after mobile build |
| Mobile torrent probe | `./scripts/try_build_mobile_torrent.sh ios` | informational (CI, continue-on-error) |

---

## Related

- [Migration index](./README.md)
- [Phase 2 — Rust engine complete](./02-rust-engine-complete.md)
- [RFC-009](../rfc/009-rust-ffi.md)
- [crates/README.md](../../crates/README.md)

Phase 1 is frozen except factual corrections. Update [02-rust-engine-complete.md](./02-rust-engine-complete.md) for active work.