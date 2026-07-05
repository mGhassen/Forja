# RFC-009: Rust core FFI

**Version:** v1.0 engine phase (web/WASM deferred to v3.0)  
**Status:** **Phase 1 complete** — B2 (mobile librqbit) deferred to [Phase 2](../migration/02-kotlin-compose.md)

## Summary

Extract performance-critical and shareable engine logic into Rust crates. Flutter consumes via C ABI (`ffi`) through `packages/rust`. Flutter UI unchanged; Dart becomes thin wrappers with fallbacks.

**Migration:** [docs/migration/README.md](../migration/README.md) · Phase 1: [01-rust-engine.md](../migration/01-rust-engine.md)

## Architecture

```
Flutter UI (apps/forja)
    → orchestrators (stream_resolver, debrid, iptv)
        → ForjaEngine facade (packages/rust)
            → libffi.dylib/.so/.dll
                → utils | stream-core | iptv-core | stremio-core | webstreamr | scrapers | torrent | proxy
```

WebView extractors (~1,900 LOC) stay in Dart/Kotlin adapters — not in the engine.

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
  torrent/       librqbit session (desktop; mobile stub)
  proxy/         axum local HTTP proxy
```

## Flutter integration

**Package:** `packages/rust/`

```dart
await ForjaEngine.init();
// Delegates wire episode matcher, HLS, IPTV, webstreamr, scrapers, torrent, proxy when dylib loads
```

**Build:**

```bash
./scripts/build_rust.sh
```

Copies dylib to `apps/forja/macos/Runner/Frameworks/` on macOS.

**Load paths:** `packages/rust/lib/src/library_path.dart` — app bundle Frameworks, walk-up to repo `crates/target/release/`, or `FORJA_RUST_LIB` env.

## Migration order

| Step | Crate | Wire-up status |
|------|-------|----------------|
| 0 | scaffold | done |
| 1 | utils | done |
| 2 | stream-core | done (5 providers) |
| 3 | iptv-core | done |
| 4 | stremio-core | done |
| 5 | webstreamr | done (fetch/registry in Dart) |
| 6 | scrapers | done |
| 7 | torrent + proxy | done (desktop librqbit; mobile libtorrent) |
| 8 | integration | done |
| 9 | cleanup | done (B2 deferred to Phase 2) |

## Tests

| Layer | Location | Command |
|-------|----------|---------|
| Rust unit | `crates/*/src` + `tests/` | `cargo test --workspace` |
| Golden fixtures | `crates/utils/tests/fixtures/`, `crates/iptv-core/tests/fixtures/` | `cargo test --test golden*` |
| Dart ↔ Rust parity | `packages/rust/test/parity/` | `flutter test` |
| CI | `.github/workflows/rust.yml` | on PR touching `crates/**` or `rust/**` |

Parity rule: **Rust output must match Dart reference** for the same fixture before switching a call site.

## Non-goals (Phase 1 — complete)

- KMP / Compose UI → [Phase 2](../migration/02-kotlin-compose.md)
- WASM build → [Phase 4](../migration/04-web-client.md)
- Replacing WebView extractors with Rust
- Full libtorrent in Rust (mobile uses libtorrent until B2)

## Acceptance

- [x] `crates/` workspace with `cargo test --workspace` green
- [x] `ffi` C ABI round-trip (`forja_add`)
- [x] `packages/rust` parity test suite
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
- [x] Step 9: runtime Dart engine removed from `lib/` (parity baselines in `test/` only)
- [ ] Drop `libtorrent_flutter` (B2) — [Phase 2 P2-21](../migration/02-kotlin-compose.md#p2-21--mobile-torrent-b2)

## Related

- [RFC-014](014-v3-web-rust.md) — web client + WASM
- [RFC-004](004-provider-registry.md) — provider registry
- [Migration index](../migration/README.md)
