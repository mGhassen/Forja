# Rust engine migration — blockers

**Last updated:** 2026-07-05  
**Migration progress:** [rust-engine-progress.md](./rust-engine-progress.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

Tracks what **blocks Step 9 cleanup** and what **must be managed** before deleting Dart engine code or shipping Rust-only.

---

## Overview

| Status | Count | IDs |
|--------|------:|-----|
| In progress | 7 | B1 · B2 · B3 · B5 · B6 · B7 · B8 |
| Open | 2 | B4 · B9 |

**Step 9 unlock:** 0 / 3 items done (see [Step 9 map](#step-9--open-work-mapped-to-blockers)).

| Metric | Done | Target |
|--------|-----:|-------:|
| Reference files consolidated | 10 | 10 |
| Reference files deleted | 0 | 10 (after B1) |
| `libtorrent_flutter` pubspec deps | 0 | 3 removed |
| Webstreamr extractor goldens | 20 | 23 |
| Webstreamr source goldens | 20 | 21 |
| M3U fixtures in Dart parity | 3 | 4 |
| Dart parity test files | 14 | 14 |
| App integration tests | 0 | ≥1 smoke |

---

## At a glance

| ID | Blocker | Severity | Progress | Blocks |
|----|---------|----------|----------|--------|
| B1 | Dart reference fallbacks still required | **high** | in progress | Delete `reference/*.dart` when all platforms ship Rust |
| B2 | `libtorrent_flutter` on mobile (+ desktop fallback) | **medium** | by design | Same magnet feature; librqbit mobile FFI not yet available |
| B3 | Dart reference layer (`packages/forja_rust/lib/src/reference/`) | **high** | in progress | Full Dart duplicate removal (tied to B1) |
| B4 | No app `integration_test/` | **medium** | open | Production sign-off on librqbit · safe libtorrent drop |
| B5 | Incomplete golden fixtures (webstreamr) | **medium** | in progress | Confidence to delete any remaining parse duplicates |
| B6 | RFC-009 parity gaps | **medium** | in progress | “Full parity suite” acceptance checkbox |
| B7 | Mobile Rust FFI packaging | **high** | in progress | Same parser engine on iOS/Android · CI mobile build |
| B8 | Dylib load / dev ergonomics | **low** | in progress | Onboarding · CI app builds without manual `build_rust.sh` |
| B9 | Stale RFC-009 migration table | **low** | open | Doc confusion only |

**Not blockers** (by design): WebView extractors · webstreamr fetcher/registry · scraper HTTP · HLS `/hls-proxy` · WASM (v3.0).

---

## Dependency chain

```
B7 mobile Rust not bundled in release builds
 └── mobile falls back to Dart reference (same features, different engine)

B1 Dart reference kept
 └── internal fallback until B7 closed on all platforms

B4 no integration tests
 └── harder to sign off platform parity in CI
```

**Unlock order (recommended):**

1. B7 — mobile Rust in CI + release APK/IPA  
2. B5 + B6 — close test gaps  
3. B4 — add smoke `integration_test/`  
4. B1 + B3 — delete reference only when all platforms bundle Rust  
5. B2 — librqbit on mobile (optional; libtorrent preserves feature until then)

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

**Progress:** in progress — iOS arm64 builds; Android NDK script added

| Done | Todo |
|------|------|
| [x] `forja-ffi` feature flags (`torrent-engine`, `local-proxy`) | [ ] librqbit on mobile (today libtorrent = same user feature) |
| [x] `scripts/build_rust_mobile.sh` + NDK discovery | [ ] README quickstart for Android devs |
| [x] Android CI (`android-ffi` job) + iOS CI (`ios-ffi` job) | |
| [x] Gradle `forjaBuildRust` / `FORJA_BUILD_RUST_ANDROID` | |
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
| [x] Production imports go through `*Backend` + reference fallback | [ ] Remove direct `StremioDartParse` imports from `stremio_service.dart` |
| [x] Parity tests still compare Rust vs reference | [ ] Scrapers import reference only from tests |

| | |
|--|--|
| **What** | 10 files under `packages/forja_rust/lib/src/reference/` used as fallbacks + parity baselines |
| **Why it blocks** | Production packages import them directly (`stremio_service.dart`, scrapers, `ForjaEngine` facade) — not dead code |
| **Files** | `m3u_dart_parser.dart` · `iptv_dart_parse.dart` · `pastesh_decrypt_dart.dart` · `stremio_dart_parse.dart` · `scrapers_dart_parse.dart` · `episode_matcher_dart.dart` · `hls_dart_parse.dart` · `js_unpacker_dart.dart` · `kisskh_decrypt_dart.dart` · `torrent_filter_dart.dart` |
| **Manage** | Keep until B1 resolved; parity tests must keep working against these |
| **Unblocks** | Step 9 “delete Dart duplicates” — engine code lives only in Rust + test fixtures |

---

### B4 — No integration tests

**Progress:** open — 0 tests

| Done | Todo |
|------|------|
| [x] Rust unit + Clippy in CI | [ ] Add `apps/forja/integration_test/` |
| [x] Dart parity 14 files / 64 tests in CI | [ ] Smoke: app boot + `ForjaEngine` loaded |
| [x] Manual checklist in progress doc | [ ] Smoke: M3U import |
| | [ ] Smoke: magnet → play (librqbit) |
| | [ ] Smoke: one stream provider URL |
| | [ ] Wire optional CI job |

| | |
|--|--|
| **What** | CI runs Rust unit + Dart parity only; app smoke is manual |
| **Why it blocks** | Cannot gate libtorrent removal or Rust-only boot on real device flows |
| **Files** | `docs/migration/rust-engine-progress.md` CI matrix — `integration_test/` optional |
| **Manage** | Add `apps/forja/integration_test/` — boot · M3U import · magnet play · one stream provider |
| **Unblocks** | B2 production sign-off · safe B1 policy change |

---

### B5 — Incomplete webstreamr golden fixtures

**Progress:** in progress — 20/23 extractors · 20/21 sources

| Done | Todo |
|------|------|
| [x] `golden_extractors.rs` — 20 tests | [ ] `kinoger` extractor golden |
| [x] `golden_sources.rs` — 20 tests | [ ] `lulustream` extractor golden |
| [x] Dart parity subset in `webstreamr_test.dart` | [ ] `fastream` extractor golden |
| [x] Dart parity subset in `webstreamr_sources_test.dart` | [ ] `kinoger` source golden |
| | [ ] `filelions` / `voe` full stream-path goldens (if distinct from redirect) |

**Missing extractor goldens:** `kinoger` · `lulustream` · `fastream`  
**Missing source golden:** `kinoger` (show.js episode URLs)

| | |
|--|--|
| **Why it blocks** | Step 9 open item; regressions on unwired golden hosts |
| **Manage** | Capture HTML fixtures from prod failures; add one golden per missing extractor |
| **Unblocks** | Step 9 checkbox; confidence deleting any stray Dart parse copies |

---

### B6 — RFC-009 parity gaps

**Progress:** in progress — core paths covered; edge-case audit open

| Done | Todo |
|------|------|
| [x] 14 parity test files in CI | [ ] RFC acceptance: tick “full parity suite” |
| [x] Episode matcher: 10/10 golden cases | [ ] Audit episode patterns vs real-world debrid filenames |
| [x] M3U: `basic` + `crlf_extgrp` + `extgrp_before_extinf` in Dart parity | [ ] Add remaining M3U edge-case fixture to Dart parity |
| [x] IPTV Xtream (categories/streams/series) · paste.sh · HLS · scrapers · stremio · proxy | [ ] Webstreamr parity: all 23 extractors (subset today) |
| [x] Utils: js unpack · kisskh · torrent filter | [ ] Document known intentional gaps |

| | |
|--|--|
| **What** | Acceptance still open: “Full parity suite (all episode patterns, all M3U edge cases)” |
| **Why it blocks** | Formal migration sign-off per RFC |
| **Files** | `docs/rfc/009-rust-ffi.md` · `packages/forja_rust/test/parity/` |
| **Manage** | Audit episode_matcher + m3u parity vs `crates/*/tests/fixtures/`; extend tests |
| **Unblocks** | RFC-009 acceptance · stronger case for B1 removal |

---

### B8 — Dylib load / dev ergonomics

**Progress:** in progress — build path exists; no auto hook on `flutter run`

| Done | Todo |
|------|------|
| [x] `./scripts/build_rust.sh` + copies to app bundle | [ ] `melos run rust:build` before first `flutter run` documented in README |
| [x] `copy_rust_dylib.sh` in macOS Xcode build phase | [ ] CI job that builds Flutter app with bundled dylib |
| [x] `FORJA_RUST_LIB` env override | [ ] Pre-run hook or fail-fast message in `bootstrap.dart` |
| [x] `melos run rust:build` · `rust:test` scripts | |
| [x] Troubleshooting section in progress doc | |

| | |
|--|--|
| **What** | Dev must run `./scripts/build_rust.sh` or set `FORJA_RUST_LIB`; otherwise boot log shows Dart fallback |
| **Why it blocks** | False negatives in manual testing; new contributors think Rust is broken |
| **Files** | `packages/forja_rust/lib/src/library_path.dart` · `apps/forja/macos/copy_rust_dylib.sh` |
| **Manage** | Document in README; consider `melos` pre-run hook or CI artifact for app builds |
| **Unblocks** | Reliable manual QA for B4/B2 |

---

### B9 — Stale RFC-009 doc

**Progress:** open — migration table not synced since steps 1–7 completed

| Done | Todo |
|------|------|
| [x] Progress tracker accurate (`rust-engine-progress.md`) | [ ] Sync RFC-009 migration order table |
| [x] Blockers doc (this file) | [ ] Sync RFC-009 acceptance checkboxes |
| | [ ] Update RFC status line (“partial wire-up” → current) |

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
| Golden fixtures for every extractor | B5 | in progress (20/23) |
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
