# RFC-009: Rust core FFI

**Version:** v3.0  
**Status:** Not started

## Summary

Extract performance-critical and shareable logic into Rust crates; consume from Flutter via FFI (native) and WASM (web).

## Crates (proposed)

```
crates/
  forja-iptv-core/      Xtream API, M3U parse, pastesh decrypt
  forja-stremio-core/   Addon manifest, catalog types
  forja-stream-core/    Provider templates, URL building
```

## Flutter integration

**Native (macOS/iOS/Android/Windows/Linux):**

```dart
// packages/forja_streaming/lib/src/rust/iptv_bindings.dart
final DynamicLibrary _lib = DynamicLibrary.open('libforja_iptv_core.so');
```

Build: `flutter build` invokes `cargo build` via `build.rs` or CI step.

**Web:**

Compile crates to WASM; load from `apps/forja/web/wasm/`. Dart interop via `dart:js_interop` or `wasm_run`.

## Migration order

1. M3U parser + Xtream JSON deserialize (pure, easy to test)
2. Provider URL templates (no I/O)
3. Pastesh / portal crypto
4. Stremio catalog (larger surface)

Dart wrappers stay thin; no UI in Rust.

## Non-goals (v3.0)

- libtorrent in Rust for web (torrent stays native-only)
- Full player in Rust

## Acceptance (v3.0)

- [ ] `forja-iptv-core` tests pass in CI
- [ ] Flutter macOS calls Rust M3U parse via FFI
- [ ] Same crate builds to WASM for web smoke test
- [ ] No regression in IPTV feature parity

## Related

RFC-010 (web client consumes WASM)
