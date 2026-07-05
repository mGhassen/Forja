# Rust engine migration — blockers

**Last updated:** 2026-07-05  
**Migration progress:** [rust-engine-progress.md](./rust-engine-progress.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

Tracks what **blocks Step 9 cleanup** and what **must be managed** before deleting Dart engine code or shipping Rust-only.

---

## Overview

| Status | Count | IDs |
|--------|------:|-----|
| In progress | 3 | B1 · B2 · B3 |
| Done / by design | 6 | B4 · B5 · B6 · B7 · B8 · B9 |

**Step 9 unlock:** 0 / 3 items done (see [Step 9 map](#step-9--open-work-mapped-to-blockers)).

| Metric | Done | Target |
|--------|-----:|-------:|
| Reference files consolidated | 10 | 10 |
| Reference files deleted | 0 | 10 (after B1) |
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
| B1 | Dart reference fallbacks still required | **high** | in progress | Delete `reference/*.dart` when all platforms ship Rust |
| B2 | `libtorrent_flutter` on mobile (+ desktop fallback) | **medium** | by design | Same magnet feature; librqbit mobile FFI not yet available |
| B3 | Dart reference layer (`packages/forja_rust/lib/src/reference/`) | **high** | in progress | Delete files (Step 9) |
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
B7 mobile Rust bundled in release builds (forjaBuildRust=true · iOS Release phase)
 └── debug mobile still needs manual build or env flags for Rust

B1 Dart reference kept
 └── delete only after release builds proven on all platforms (Step 9)
```

**Unlock order (recommended):**

1. B1 + B3 — delete reference when release Rust proven on all platforms  
2. B6 — RFC Step 9 sign-off (lulustream/fastream gap documented)  
3. B2 — librqbit on mobile (optional; libtorrent preserves feature until then)

---

## Blocker details

### B1 — Dart reference fallbacks

**Progress:** in progress — consolidated in `reference/`; Rust always attempted at boot

| Done | Todo |
|------|------|
| [x] Rust always loaded at boot (`ForjaEngine.init()`) | [ ] Remove `*Backend` fallbacks only after all platforms bundle Rust |
| [x] Developer toggle removed | [ ] Delete `reference/*.dart` when CI proves mobile + desktop Rust |
| [x] All domain delegates when dylib loads | |

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
| **Why it blocks** | Platform parity — without bundled `.so`/`.dylib`, mobile falls back to Dart reference |
| **Files** | `scripts/build_rust_mobile.sh` · `library_path.dart` · `facade.dart` · `android/.../jniLibs/` · `ios/Runner/Frameworks/` |
| **Manage** | Mobile FFI ships parsers + webstreamr; torrent stays libtorrent until librqbit compiles on iOS/Android |
| **Unblocks** | Single engine path for IPTV/Stremio/scrapers on all native platforms |

---

### B2 — `libtorrent_flutter` dependency

**Progress:** by design on mobile; desktop uses librqbit when Rust loads

| Done | Todo |
|------|------|
| [x] Desktop: `TorrentStreamService` prefers Rust/librqbit | [ ] librqbit in mobile Rust FFI (same magnet feature) |
| [x] Mobile: libtorrent = torrent engine (feature preserved) | [ ] Port `applyConnectionsLimit` when Rust torrent on mobile |
| [x] Magnet player via `TorrentStreamService` | |
| [x] FFI torrent stubs on mobile build (`--no-default-features`) | |

| | |
|--|--|
| **What** | Native torrent engine still linked in `apps/forja`, `forja_streaming`, `forja_api` |
| **Why it blocks** | `TorrentStreamService.start()` falls back to libtorrent when Rust port is 0 or `TorrentEngineBackend` unset; `applyConnectionsLimit` only touches libtorrent session |
| **Files** | `packages/forja_streaming/lib/src/torrent_stream_service.dart` · `apps/forja/pubspec.yaml` |
| **Manage** | Dogfood librqbit on desktop; log fallback rate; port connection-limit config to Rust or drop feature |
| **Unblocks** | Step 9 checkbox “Drop libtorrent_flutter”; RFC-010/014 web builds without native torrent |

---

### B3 — Dart reference layer

**Progress:** in progress — consolidated; 0 files deleted

| Done | Todo |
|------|------|
| [x] 10 modules moved to `reference/` (single location) | [ ] Delete `reference/*.dart` after B1 |
| [x] Dead dupes removed (`hls_master_parser`, `debrid_api` in streaming) | [ ] Move parity baselines to `test/fixtures/` only |
| [x] Production imports go through `*Backend` hooks only | |
| [x] `installDartFallbackDelegates()` in app bootstrap | |
| [x] Parity tests still compare Rust vs reference | |

| | |
|--|--|
| **What** | 10 files under `reference/` — parity baselines + `dart_fallback_delegates.dart` only |
| **Why it blocks** | Step 9 deletes these once release Rust is proven on all platforms |
| **Files** | `m3u_dart_parser.dart` · `iptv_dart_parse.dart` · `pastesh_decrypt_dart.dart` · `stremio_dart_parse.dart` · `scrapers_dart_parse.dart` · `episode_matcher_dart.dart` · `hls_dart_parse.dart` · `js_unpacker_dart.dart` · `kisskh_decrypt_dart.dart` · `torrent_filter_dart.dart` |
| **Manage** | Keep until B1 resolved; parity tests must keep working against these |
| **Unblocks** | Step 9 “delete Dart duplicates” — engine code lives only in Rust + test fixtures |

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

| | |
|--|--|
| **What** | CI runs Rust unit + Dart parity only; app smoke is manual |
| **Why it blocks** | Cannot gate libtorrent removal or Rust-only boot on real device flows |
| **Files** | `docs/migration/rust-engine-progress.md` CI matrix — `integration_test/` optional |
| **Manage** | Add `apps/forja/integration_test/` — boot · M3U import · magnet play · one stream provider |
| **Unblocks** | B2 production sign-off · safe B1 policy change |

---

### B5 — Webstreamr golden fixtures

**Progress:** done — 23/23 extractors · 21/21 sources · Dart parity 21/23

| Done | Todo |
|------|------|
| [x] `golden_extractors.rs` — 25 tests (all extractors) | [ ] Optional: filelions/voe full stream-path goldens |
| [x] `golden_sources.rs` — 21 tests | |
| [x] kinoger · lulustream · fastream Rust goldens | |
| [x] Dart parity: 21/23 extractors + 22/22 sources | |

| | |
|--|--|
| **Why it blocks** | Step 9 open item; regressions on unwired golden hosts |
| **Manage** | Capture HTML fixtures from prod failures; add one golden per missing extractor |
| **Unblocks** | Step 9 checkbox; confidence deleting any stray Dart parse copies |

---

### B6 — RFC-009 parity gaps

**Progress:** done — lulustream/fastream stream-fetch documented as Rust-only

| Done | Todo |
|------|------|
| [x] RFC acceptance: core parity suite (documented gaps) | |
| [ ] lulustream · fastream stream-fetch (Rust golden only) | |

| | |
|--|--|
| **What** | Acceptance still open: “Full parity suite (all episode patterns, all M3U edge cases)” |
| **Why it blocks** | Formal migration sign-off per RFC |
| **Files** | `docs/rfc/009-rust-ffi.md` · `packages/forja_rust/test/parity/` |
| **Manage** | RFC sign-off tick; optional lulustream/fastream Dart stream-fetch if harness gains native HTTP mock |
| **Unblocks** | RFC-009 acceptance · stronger case for B1 removal |

**Known intentional gaps (not bugs):**

- `lulustream` / `fastream` — MFP **stream URL fetch** (blocking HTTP inside Rust FFI) is covered by Rust goldens + wiremock only; Dart parity tests MFP **redirect** extractors (mixdrop, streamtape, …) instead.
- `Show.3.07` dot-separated season.episode (no `S` / `x`) — use torrent title filter or manual pick
- Anime packs with episode-only names (`Show - 07`) — `pickEpisode` episode-only fallback when pack has no `SxxExx` markers
- `Sample` in filename — excluded in `pickEpisode` / `is_video`, not in `matches()`

---

### B8 — Dylib load / dev ergonomics

**Progress:** done

| Done | Todo |
|------|------|
| [x] `./scripts/build_rust.sh` + copies to app bundle | [ ] Optional: CI job that builds full Flutter app artifact |
| [x] `apps/forja/README.md` + `crates/README.md` quickstart | |
| [x] Debug warning when Rust missing on desktop (`bootstrap.dart`) | |
| [x] `FORJA_RUST_LIB` env · `FORJA_RUST_STRICT=1` | |
| [x] `melos run rust:build` · `rust:test` · `rust:integration` | |
| [x] Troubleshooting in progress doc | |

| | |
|--|--|
| **What** | Dev must run `./scripts/build_rust.sh` or set `FORJA_RUST_LIB`; otherwise boot log shows Dart fallback |
| **Why it blocks** | False negatives in manual testing; new contributors think Rust is broken |
| **Files** | `packages/forja_rust/lib/src/library_path.dart` · `apps/forja/macos/copy_rust_dylib.sh` |
| **Manage** | Document in README; consider `melos` pre-run hook or CI artifact for app builds |
| **Unblocks** | Reliable manual QA for B4/B2 |

---

### B9 — RFC-009 sync

**Progress:** done (living doc — update status line when Step 9 completes)

| Done | Todo |
|------|------|
| [x] Progress tracker accurate | [ ] RFC status line → “done” when Step 9 completes |
| [x] Migration order table synced | |
| [x] Acceptance checkboxes synced (partial) | |

| | |
|--|--|
| **What** | RFC migration table still says “1 extractor”, “not wired”, “stubs only” |
| **Why it blocks** | Planning confusion only |
| **Manage** | Sync RFC table + acceptance with `rust-engine-progress.md` when touching docs |
| **Unblocks** | Nothing runtime |

---

## Step 9 — open work mapped to blockers

| Step 9 item | Blocker(s) | Progress |
|-------------|------------|----------|
| Drop `libtorrent_flutter` | B1 · B2 · B4 | open |
| Golden fixtures for every extractor | B5 | done |
| App `integration_test/` smoke | B4 | done (core) |
| (implicit) delete `reference/*.dart` | B1 · B3 · B6 | open (consolidation done) |

Completed Step 9 items (reference consolidation, dead file removal) do **not** remove blockers — they organized fallbacks, not deleted them.

---

## Explicit non-blockers

Do **not** track these as migration blockers:

| Item | Reason |
|------|--------|
| `forja_adapters/` WebView package | Never existed; WebView stays in app per RFC-009 |
| Webstreamr fetcher / registry / page HTTP | Orchestration stays Dart (same as scraper HTTP) |
| HLS `/hls-proxy` | Out of Rust scope; shelf rewrite in Dart |
| WASM / web client | RFC-014 v3.0 |
| KMP / Compose | Out of scope |

---

## Updating this doc

When a blocker is resolved or a new one appears:

1. Update **overview** in this file only (counts, metrics, Done/Todo).
2. Update [rust-engine-progress.md](./rust-engine-progress.md) Step 9 checkboxes only — do not duplicate blocker tables there.
3. Update [RFC-009](../rfc/009-rust-ffi.md) if acceptance affected.

See `.cursor/rules/rust-migration.mdc`.
