# Phase 2 — Playback engine (wave 1)

**Status:** 35 / 41 tasks ✅ — open: P2-11, P2-14, P2-52, P2-70 → P2-72  
**Depends on:** [Phase 1 complete](./01-rust-engine.md)  
**Next phase:** [Phase 3 — Catalog engine (wave 2)](./03-engine-catalog.md)  
**Migration index:** [README.md](./README.md)  
**Boundary:** [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

---

## Goal

Playback-path engine lives in `crates/*`. Delete `packages/{streaming,storage,core}` and playback slices of `packages/api`.

Catalog engine (`packages/api` verticals) is **Phase 3** — same destination (`crates/*`), different schedule.

---

## Status at a glance

| | |
|--|--|
| **Progress** | **35 / 41** wave-1 tasks ✅ |
| **Blocks wave 2** | P2-11, P2-14, P2-52, P2-70 → P2-72 |
| **Deferred to Phase 3** | P2-89 (Stremio catalog service) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (Phase 3)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | P2-10 | Fix librqbit iOS/Android build (vendored dualstack patch) | ✅ |
| 2 | P2-11 | Android NDK full-features build in CI | ⬜ |
| 3 | P2-12 | Mobile build script defaults to full Rust features | ✅ |
| 4 | P2-13 | Wire torrent on mobile (same path as desktop) | ✅ |
| 5 | P2-14 | Magnet → HTTP stream E2E on iOS/Android device | ⬜ |
| 6 | P2-15 | `applyConnectionsLimit` → librqbit `peer_limit` | ✅ |
| 7 | P2-20 | Remove `libtorrent_flutter` from pubspecs | ✅ |
| 8 | P2-21 | `torrent_stream_service.dart` — Rust-only, no libtorrent branch | ✅ |
| 9 | P2-22 | Remove libtorrent from player/magnet call sites | ✅ |
| 10 | P2-23 | Bootstrap `cleanup()` — librqbit teardown only | ✅ |
| 11 | P2-30 | Webstreamr: remove Dart HTML parse fallbacks | ✅ |
| 12 | P2-31 | Delete orphan engine copies (`dart_fallback/`, `reference/`) | ✅ |
| 13 | P2-32 | Provider registry: remove static Dart URL fallbacks | ✅ |
| 14 | P2-33 | Scrapers: remove Dart parse for knaben/tpb/uindex | ✅ |
| 15 | P2-50 | Expand `forja.udl` for Kotlin/uniffi | ✅ |
| 16 | P2-51 | uniffi Kotlin bindgen scaffold | ✅ |
| 17 | P2-52 | JNI packaging proof (reuse mobile `.so` / `.dylib`) | ⬜ |
| 18 | P2-60 | Delete legacy `packages/forja_*` duplicates | ✅ |
| 19 | P2-61 | `packages/rust/lib/src/` — loader only (3 files) | ✅ |
| 20 | P2-62 | Drop Dart parity baselines; Rust goldens only | ✅ |
| 21 | P2-63 | Audit `melos.yaml` / CI for `forja_*` refs | ✅ |
| 22 | P2-64 | Zero Dart engine in active packages | ✅ |
| 23 | P2-80 | High-level FFI surface — one call per user action | ✅ |
| 24 | P2-81 | Scraper pipeline → `search_torrents_json` in `crates/scrapers` | ✅ |
| 25 | P2-82 | Webstreamr pipeline → `crates/webstreamr`; delete `packages/webstreamr` | ✅ |
| 26 | P2-83 | Stream resolver → `crates/stream_core`; delete `packages/streaming` | ✅ |
| 27 | P2-84 | Torrent filter → `filter_torrents_json` | ✅ |
| 28 | P2-85 | HLS proxy in `crates/proxy`; drop shelf engine routes | ✅ |
| 29 | P2-86 | Delete all `*Backend` hooks + `rust_delegates.dart` | ✅ |
| 30 | P2-87 | Delete `packages/scrapers` | ✅ |
| 31 | P2-88 | Delete `packages/storage` → `crates/storage` + `packages/rust` | ✅ |
| 32 | P2-89 | Stremio catalog service → `crates/stremio-core` | ⏭️ Phase 3 |
| 33 | P2-90 | Delete `packages/core` → `api/models` + app utils | ✅ |
| 34 | P2-91 | WebStreamr `Isolate.run` offload + `cancelPending()` — [issue 001](../issues/001-webstreamr-blocks-ui.md) | ✅ |
| 35 | P2-92 | Consolidate loopback servers in `crates/proxy` (111477 captcha/CF still Dart — known gap) | ✅ |
| 36 | P2-93 | Stremio HTTP via `stremioHttpGet` (kill Dart HTTP split) | ✅ |
| 37 | P2-94 | IPTV HTTP + stream probe via `iptv_probe_stream_json` | ✅ |
| 38 | P2-95 | Delete dead repos, unused Dart scrapers, `StreamResolver` | ✅ |
| 39 | P2-96 | Move `app_theme.dart` → `apps/forja/lib/shared/theme/` | ✅ |
| 40 | P2-70 | Manual smoke — magnet E2E, stream resolve, scraper search via FFI | 🔄 |
| 41 | P2-71 | Update RFC-009 — mark Step 9 + B2 + wave 1 complete | ⬜ |
| 42 | P2-72 | Mark Phase 2 complete in README → unlock Phase 3 | ⬜ |

---

## Playback engine exit checklist

**Wave 2 starts when all rows are ✅.**

| # | Criterion | Task | Status |
|---|-----------|------|--------|
| T1 | `packages/streaming` deleted | P2-83, P2-92 | ✅ |
| T2 | `packages/storage` deleted | P2-88, P2-96 | ✅ |
| T3 | `packages/core` deleted | P2-90 | ✅ |
| T4 | WebStreamr non-blocking | P2-91 | ✅ |
| T5 | Stremio/IPTV no fetch split-brain | P2-93, P2-94 | ✅ |
| T6 | Mobile magnet E2E | P2-14 | ⬜ |
| T7 | No engine logic in `apps/forja/features/*/data/` except host adapters | — | ✅ |
| T8 | Sign-off | P2-70 → P2-72 | 🔄 docs updated; P2-71/72 open |

---

## Migration rule

| Step | Action |
|------|--------|
| 1 | Port engine logic → Rust crate |
| 2 | Add FFI in `crates/ffi` (fetch+parse, Pattern B) |
| 3 | UI calls `Engine.*` / `RustLib.*` |
| 4 | **Delete the Dart equivalent** — directory slice, deps, imports |

### `packages/` after wave 1

| Package | Purpose |
|---------|---------|
| `packages/rust` | Dart FFI bridge + host prefs (**permanent**) |
| `packages/api` | Catalog + thin playback glue (`lib/playback/`) — catalog ports Phase 3 |

---

## Architecture

```
UI (apps/forja — Flutter permanent host)
  → widgets, navigation, player chrome, Nuvio (flutter_js)
  → calls Engine / RustLib for engine paths

Engine (crates/* + libffi)
  → playback: stream resolve, torrent, proxy, storage, parsers

packages/api/lib/playback/
  → thin Dart wrappers over Rust FFI (torrent, proxy, webstreamr, extractors)
```

| **Engine (`crates/*`)** | **Host (`apps/forja`)** |
|-------------------------|-------------------------|
| Stream resolve, torrent, proxy | Player (media_kit) |
| Storage KV, parsers | WebView, Nuvio, WASM |
| Parse, crypto, extract (playback) | OAuth, secure storage, theme |
| | Theme presets, navigation |

**Anti-patterns:** Dart wrapper instead of delete · sync FFI on UI thread (use isolate, P2-91) · Pattern A FFI · new engine logic in Dart · `*Backend` hooks

**Allowed:** host orchestration for provider race UX · `Isolate.run` for long FFI · thin playback glue in `api/playback/` until Phase 3

---

## Quick health check

```bash
./scripts/build_rust.sh
cd crates && cargo test --workspace
cd packages/rust && flutter test test/parity/   # 123 tests

# Optional desktop magnet E2E (slow, needs network):
TORRENT_E2E=1 TORRENT_MAGNET='magnet:?...' flutter test integration_test/engine_smoke_test.dart

# Mobile FFI:
./scripts/build_rust_mobile.sh all
melos run rust:release-check
```

---

## Related

- [Phase 1](./01-rust-engine.md) · [Phase 3 catalog](./03-engine-catalog.md) · [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) · [RFC-009](../rfc/009-rust-ffi.md)
