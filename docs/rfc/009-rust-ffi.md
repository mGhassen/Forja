# RFC-009: Rust core FFI

**Version:** v1.0 engine phase (web/WASM deferred to v3.0)  
**Status:** **In progress** — Steps 0–8 done; Step 9 cleanup blocked on reference deletion (B1)

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
  forja-webstreamr/    23 extractors + 21 sources (HTML/JSON parse in Rust)
  forja-scrapers/      Knaben, TPB, Uindex HTML parsers
  forja-torrent/       librqbit session (desktop; mobile stub)
  forja-proxy/         axum local HTTP proxy
```

## Flutter integration

**Package:** `packages/forja_rust/`

```dart
await ForjaEngine.init();
// Delegates wire episode matcher, HLS, IPTV, webstreamr, scrapers, torrent, proxy when dylib loads
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
| 1 | forja-utils | done |
| 2 | forja-stream-core | done (5 providers) |
| 3 | forja-iptv-core | done |
| 4 | forja-stremio-core | done |
| 5 | forja-webstreamr | done (fetch/registry in Dart) |
| 6 | forja-scrapers | done |
| 7 | torrent + proxy | done (desktop librqbit; mobile libtorrent) |
| 8 | integration | done |
| 9 | cleanup | in progress |

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
- [x] Full M3U golden parity (4 fixtures)
- [x] Episode matcher golden parity (18 match + 3 pick cases)
- [x] Webstreamr Rust golden suite (23 extractors · 21 sources)
- [x] Webstreamr Dart FFI parity (21/23 extractors · 22/22 sources)
- [x] App engine smoke tests (`integration_test/` — 11 tests in CI)
- [x] Mobile release bundles Rust parsers (Android `forjaBuildRust=true` · iOS Release build phase)
- [x] Full parity suite (core paths; lulustream/fastream stream-fetch documented gap)
- [ ] WASM smoke test (v3.0)
- [ ] Step 9: delete Dart `reference/` when all platforms proven in release

## Related

- [RFC-014](014-v3-web-rust.md) — web client + WASM
- [RFC-004](004-provider-registry.md) — provider registry
- [Migration progress](../migration/rust-engine-progress.md)
