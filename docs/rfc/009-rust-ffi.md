# RFC-009: Rust core FFI

**Version:** v1.0 engine phase (web/WASM deferred to v3.0)  
**Status:** **In progress** — crates + FFI + partial Flutter wire-up

## Summary

Extract performance-critical and shareable engine logic into Rust crates. Flutter consumes via C ABI (`forja-ffi`) through `packages/forja_rust`. Flutter UI unchanged; Dart becomes thin wrappers with fallbacks.

**Progress tracker:** [docs/migration/rust-engine-progress.md](../migration/rust-engine-progress.md)

## Architecture

```
Flutter UI (apps/forja)
    → orchestrators (stream_resolver, debrid, iptv)
        → ForjaEngine facade (packages/forja_rust)
            → libforja_ffi.dylib/.so/.dll
                → forja-utils | stream-core | iptv-core | stremio-core | webstreamr | scrapers | torrent | proxy
```

WebView extractors (~1,900 LOC) stay in Dart/Kotlin adapters — not in the engine.

## Crates

```
crates/
  forja-ffi/           C ABI + uniffi scaffold
  forja-utils/         episode_matcher, torrent_filter, js_unpacker, hls_parser, kisskh_subtitle
  forja-stream-core/   provider URL templates (vidlink, vixsrc, vidnest)
  forja-iptv-core/     M3U parser, Xtream JSON, paste.sh crypto
  forja-stremio-core/  manifest parse, resource URL builder
  forja-webstreamr/    types + vidsrc extractor (1/49)
  forja-scrapers/      Knaben, TPB, Uindex HTML parsers
  forja-torrent/       session stub (libtorrent later)
  forja-proxy/         axum local HTTP proxy skeleton
```

## Flutter integration

**Package:** `packages/forja_rust/`

```dart
await ForjaEngine.init();
// EpisodeMatcher, HlsParser, M3uParser route through delegates when isReady
```

**Build:**

```bash
./scripts/build_rust.sh
```

Copies dylib to `apps/forja/macos/Runner/Frameworks/` on macOS.

**Load paths:** `packages/forja_rust/lib/src/library_path.dart` — app bundle Frameworks, walk-up to repo `crates/target/release/`, or `FORJA_RUST_LIB` env.

## Migration order

| Step | Crate | Wire-up status |
|------|-------|----------------|
| 0 | scaffold | done |
| 1 | forja-utils | delegates for episode + HLS; torrent_filter FFI only |
| 2 | forja-stream-core | 3 providers wired |
| 3 | forja-iptv-core | M3U wired |
| 4 | forja-stremio-core | not wired |
| 5 | forja-webstreamr | not wired (1 extractor in Rust) |
| 6 | forja-scrapers | not wired |
| 7 | torrent + proxy | stubs only |
| 8 | integration | partial |

## Tests

| Layer | Location | Command |
|-------|----------|---------|
| Rust unit | `crates/*/src` + `tests/` | `cargo test --workspace` |
| Golden fixtures | `crates/forja-utils/tests/fixtures/`, `crates/forja-iptv-core/tests/fixtures/` | `cargo test --test golden*` |
| Dart ↔ Rust parity | `packages/forja_rust/test/parity/` | `flutter test` |
| CI | `.github/workflows/rust.yml` | on PR touching `crates/**` or `forja_rust/**` |

Parity rule: **Rust output must match Dart reference** for the same fixture before switching a call site.

## Non-goals (current phase)

- KMP / Compose UI
- WASM build (v3.0)
- Replacing WebView extractors with Rust
- Full libtorrent in Rust (stub only)
- Deleting Dart engine code (until parity proven)

## Acceptance

- [x] `crates/` workspace with `cargo test --workspace` green
- [x] `forja-ffi` C ABI round-trip (`forja_add`)
- [x] `packages/forja_rust` parity test suite
- [x] CI workflow `rust.yml`
- [x] `ForjaEngine.init()` in app bootstrap
- [x] M3U parse via FFI in IPTV path
- [x] Provider URLs (vidlink, vixsrc, vidnest) via FFI
- [x] Dylib loads on `flutter run -d macos` without env override
- [x] Stremio URL helpers wired (`buildResourceUrl`, split, normalize)
- [x] Scrapers HTML parse + dedup wired
- [ ] Full parity suite (all episode patterns, all M3U edge cases)
- [ ] WASM smoke test (v3.0)

## Related

- [RFC-014](014-v3-web-rust.md) — web client + WASM
- [RFC-004](004-provider-registry.md) — provider registry
- [Migration progress](../migration/rust-engine-progress.md)
