# Forja Rust engine

Workspace crates consumed by Flutter via `packages/forja_rust` (FFI).

**Progress:** [docs/migration/rust-engine-progress.md](../docs/migration/rust-engine-progress.md)  
**Spec:** [docs/rfc/009-rust-ffi.md](../docs/rfc/009-rust-ffi.md)

## Build

```bash
./scripts/build_rust.sh                    # desktop (torrent + proxy + parsers)
./scripts/build_rust_mobile.sh ios         # iOS arm64 parsers
./scripts/build_rust_mobile.sh android     # Android arm64-v8a parsers
./scripts/build_rust_mobile.sh all         # both mobile targets
```

Mobile builds use `forja-ffi --no-default-features` (parsers + webstreamr only; no librqbit/proxy). Magnet playback on mobile stays `libtorrent_flutter` until librqbit compiles on iOS/Android.

### Android NDK

Requires NDK r26+ (Android Studio → SDK Manager → NDK, or `sdkmanager ndk`).

Set one of:

- `ANDROID_NDK_HOME` / `ANDROID_NDK_ROOT`
- `sdk.dir` in `apps/forja/android/local.properties` (Gradle discovers `ndk/` under the SDK)

Output: `apps/forja/android/app/src/main/jniLibs/arm64-v8a/libforja_ffi.so`

Release build with Rust bundled:

```bash
./scripts/build_rust_mobile.sh android
FORJA_BUILD_RUST_ANDROID=1 flutter build apk
# or forjaBuildRust=true in apps/forja/android/gradle.properties
```

### iOS

Requires macOS + Xcode. Output: `apps/forja/ios/Runner/Frameworks/libforja_ffi.dylib` (Xcode copy phase).

## Test

```bash
melos run rust:test           # cargo + Dart parity
melos run rust:integration    # app engine smoke (desktop)
```

Or manually:

```bash
cd crates && cargo test --workspace
cd packages/forja_rust && flutter test
cd apps/forja && flutter test integration_test/
```

## Crates

| Crate | Role |
|-------|------|
| `forja-ffi` | C ABI entry point |
| `forja-utils` | episode matcher, torrent filter, unpacker, HLS, kisskh |
| `forja-stream-core` | provider URL templates (5 providers) |
| `forja-iptv-core` | M3U, Xtream JSON, paste.sh crypto |
| `forja-stremio-core` | Stremio manifest/URL/HTTP helpers |
| `forja-webstreamr` | 23 extractors + 21 sources |
| `forja-scrapers` | Knaben/TPB/Uindex HTML parsers |
| `forja-torrent` | librqbit session (desktop FFI) |
| `forja-proxy` | local HTTP proxy (axum) |
