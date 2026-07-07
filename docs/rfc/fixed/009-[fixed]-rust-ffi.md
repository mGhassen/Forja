# RFC-009: Rust core FFI

**Version:** v1.0 engine phase (web/WASM deferred to v3.0)  
**Status:** fixed — Phases 1–3 engine migration complete ([migration index](../../migration/README.md))  
**Boundary:** [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)

## Summary

Extract engine logic into Rust crates. Flutter consumes via C ABI (`ffi`) through `packages/rust`. ~~`packages/api`~~ deleted in P3-03; playback + catalog glue lives in `packages/rust/lib/src/`.

**Migration:** [docs/migration/README.md](../migration/README.md) · [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)

## Architecture

```
Flutter UI (apps/forja)
    → host: provider race UX, player, WebView adapters
        → ForjaEngine facade (packages/rust)
            → libffi.dylib/.so/.dll
                → utils | stream-core | iptv-core | stremio-core | webstreamr | scrapers | torrent | proxy | storage
```

Host orchestration for provider order and loading UX — see [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) R6. WebView extractors (~1,900 LOC) stay in Dart/Kotlin adapters.

## Crates

```
crates/
  ffi/           C ABI + uniffi scaffold
  utils/         episode_matcher, torrent_filter, js_unpacker, hls_parser, kisskh_subtitle
  stream-core/   provider URL templates (vidlink, vixsrc, vidnest)
  iptv-core/     M3U parser, Xtream JSON, paste.sh crypto
  stremio-core/  manifest parse, resource URL builder
  webstreamr/    23 extractors + 21 sources (HTML/JSON parse in Rust)
  scrapers/      Knaben, TPB, Uindex HTML parsers
  torrent/       librqbit session (desktop + iOS/Android via libffi)
  proxy/         axum local HTTP proxy
```

## Flutter integration

**Package:** `packages/rust/`

```dart
await Engine.init();
// Delegates wire episode matcher, HLS, IPTV, webstreamr, scrapers, torrent, proxy when dylib loads
```

**Build:**

```bash
./scripts/build_rust.sh
```

Copies dylib to `apps/forja/macos/Runner/Frameworks/` on macOS.

**Load paths:** `packages/rust/lib/src/library_path.dart` — app bundle Frameworks, walk-up to repo `crates/target/release/`, or `RUST_LIB` env.

## Migration order

| Step | Crate | Wire-up status |
|------|-------|----------------|
| 0 | scaffold | done |
| 1 | utils | done |
| 2 | stream-core | done (5 providers) |
| 3 | iptv-core | done |
| 4 | stremio-core | done |
| 5 | webstreamr | done — fetch+resolve in Rust (`webstreamr_get_streams_json`) |
| 6 | scrapers | done |
| 7 | torrent + proxy | done (librqbit desktop + mobile) |
| 8 | integration | done |
| 9 | playback + catalog cleanup | ✅ — `streaming`/`storage`/`core`/`api` deleted; glue in `packages/rust` |

## FFI patterns

| Pattern | Description | Status |
|---------|-------------|--------|
| **B — fetch+parse** | Rust performs HTTP and parsing (`webstreamr_get_streams_json`, `search_torrents_json`, `stremio_http_get_json`) | **Default** |
| **A — parse-only** | Caller supplies HTML/body (`extract_*_html_json`, `parse_stremio_*_json`) | Legacy; do not add for engine work |

## Threading

FFI resolve/search entry points must **not block the UI thread**.

- **Long I/O** (webstreamr, vidsrc, stremio HTTP, torrent search, IPTV HTTP): [`EngineJobs`](../../packages/rust/lib/src/engine_jobs.dart) — Rust tokio runtime, poll-based completion.
- **CPU work** (parse, filter, decrypt): [`EngineWorkerPool`](../../packages/rust/lib/src/engine_worker.dart) — 3 worker isolates.

**Engine (shipped — [issue 015](../issues/fixed/015-[fixed]-rust-blocking-http-engine-debt.md)):**

| Area | Behavior |
|------|----------|
| `webstreamr` | Shared async `reqwest::Client` + tokio runtime; primary sources resolve in parallel (rayon) with early exit at 8 playable URLs |
| `stremio-core` | Shared async HTTP client + runtime (no per-call `Runtime::new()`) |
| `scrapers` | Parallel async `search_all`; FFI entry still sync via shared tokio runtime |
| Cancel | `CancellationToken` + `tokio::select!` aborts in-flight HTTP; `engine_cancel_pending()` cancels all jobs |
| Dart I/O | `EngineJobs` — submit/poll on Rust tokio runtime (main isolate free) |
| Dart CPU | `EngineWorkerPool` — parse/decrypt/filter on pooled worker isolates |

## Tests

| Layer | Location | Command |
|-------|----------|---------|
| Rust unit | `crates/*/src` + `tests/` | `cargo test --workspace` |
| Golden fixtures | `crates/utils/tests/fixtures/`, `crates/iptv-core/tests/fixtures/` | `cargo test --test golden*` |
| Dart ↔ Rust parity | `packages/rust/test/parity/` | `flutter test` |
| CI | `.github/workflows/rust.yml` | on PR touching `crates/**` or `rust/**` |

Parity rule: **Rust output must match Dart reference** for the same fixture before switching a call site.

## Non-goals (Phase 1 — complete)

- WASM build → [RFC-014](../014-[draft]-v3-web-rust.md) (v3.0, not migration)
- Replacing WebView extractors with Rust
- Full libtorrent removed — librqbit on all platforms (P2-20 → P2-23)

## Acceptance

- [x] `crates/` workspace with `cargo test --workspace` green
- [x] `ffi` C ABI round-trip (`ffi_add`)
- [x] `packages/rust` parity test suite
- [x] CI workflow `rust.yml`
- [x] `Engine.init()` in app bootstrap
- [x] M3U parse via FFI in IPTV path
- [x] Provider URLs (vidlink, vixsrc, vidnest) via FFI
- [x] Dylib loads on `flutter run -d macos` without env override
- [x] Stremio URL helpers wired (`buildResourceUrl`, split, normalize)
- [x] Scrapers HTML parse + dedup wired
- [x] Full M3U golden parity (4 fixtures)
- [x] Episode matcher golden parity (18 match + 3 pick cases)
- [x] Webstreamr Rust golden suite (23 extractors · 21 sources)
- [x] Webstreamr Dart FFI parity (21/23 extractors · 22/22 sources)
- [x] App engine smoke tests (`apps/forja/test/engine_smoke_test.dart` — 13 tests in CI)
- [x] Mobile release bundles Rust parsers (Android `buildRust=true` · iOS Release build phase)
- [x] Full parity suite (core paths; lulustream/fastream stream-fetch documented gap)
- [ ] WASM smoke test (v3.0)
- [x] Step 9: playback Dart engine deleted (`streaming`/`storage`/`core`; parity in `packages/rust/test/`)
- [x] B2: `libtorrent_flutter` dropped — librqbit via `crates/torrent` (P2-20 → P2-23)
- [x] Device magnet E2E on iOS/Android (P2-14) — `mobile_magnet_e2e_test.dart` + CI `android-magnet-e2e`

## Related

- [RFC-014](../014-[draft]-v3-web-rust.md) — web client + WASM
- [RFC-004](../004-[partial]-provider-registry.md) — provider registry
- [Migration index](../migration/README.md)
