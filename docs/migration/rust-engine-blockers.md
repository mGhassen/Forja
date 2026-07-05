# Rust engine migration — blockers

**Last updated:** 2026-07-05  
**Migration progress:** [rust-engine-progress.md](./rust-engine-progress.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

Tracks what **blocks Step 9 cleanup** and what **must be managed** before shipping Rust-only.

---

## Overview

| Status | Count | IDs |
|--------|------:|-----|
| In progress | 1 | B2 |
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
| B2 | `libtorrent_flutter` on mobile (+ desktop fallback) | **medium** | by design | Drop libtorrent from pubspecs |
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

**Unlock order (recommended):**

1. B2 — librqbit on mobile (optional; libtorrent preserves feature until then)

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
| KMP / Compose | Out of scope |
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
