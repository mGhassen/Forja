# Forja Rust engine

Workspace crates consumed by Flutter via `packages/forja_rust` (FFI, transitional).

**Migration:** [docs/migration/README.md](../docs/migration/README.md) · Phase 1: [01-rust-engine.md](../docs/migration/01-rust-engine.md) · **Active:** [02-rust-engine-complete.md](../docs/migration/02-rust-engine-complete.md)

## Build

```bash
./scripts/build_rust.sh                    # desktop (torrent + proxy + parsers)
./scripts/build_rust_mobile.sh ios         # iOS arm64 parsers
./scripts/build_rust_mobile.sh android     # Android arm64-v8a parsers
./scripts/build_rust_mobile.sh all         # both mobile targets
```

Mobile builds use `ffi --no-default-features` (parsers + webstreamr only; no librqbit/proxy). Magnet playback on mobile uses `libtorrent_flutter` until librqbit compiles on iOS/Android (blocked: `librqbit-dualstack-sockets` → `bind_device` on iOS). Probe: `./scripts/try_build_mobile_torrent.sh ios`.

### Android NDK

Requires NDK r26+ (Android Studio → SDK Manager → NDK, or `sdkmanager ndk`).

Set one of:

- `ANDROID_NDK_HOME` / `ANDROID_NDK_ROOT`
- `sdk.dir` in `apps/forja/android/local.properties` (Gradle discovers `ndk/` under the SDK)

Output: `apps/forja/android/app/src/main/jniLibs/arm64-v8a/libffi.so`

Release APK bundles Rust automatically (`forjaBuildRust=true` → `preReleaseBuild`):

```bash
flutter build apk
```

Debug with Rust:

```bash
FORJA_BUILD_RUST_ANDROID=1 flutter run -d android
```

### iOS

Requires macOS + Xcode. Release/Profile builds compile Rust via `build_rust_ios.sh`; output lands in `apps/forja/ios/Runner/Frameworks/libffi.dylib` (Xcode copy phase embeds it).

Debug: run `./scripts/build_rust_mobile.sh ios` once, or set `FORJA_BUILD_RUST_IOS=0` to skip the release build phase.

## Test

```bash
melos run rust:test           # cargo + Dart parity
melos run rust:integration    # app engine smoke (desktop)
```

Or manually:

```bash
cd crates && cargo test --workspace
cd packages/rust && flutter test
cd apps/forja && flutter test integration_test/
```

## Crates

| Crate | Role |
|-------|------|
| `ffi` | C ABI entry point |
| `utils` | episode matcher, torrent filter, unpacker, HLS, kisskh |
| `stream-core` | provider URL templates (5 providers) |
| `iptv-core` | M3U, Xtream JSON, paste.sh crypto |
| `stremio-core` | Stremio manifest/URL/HTTP helpers |
| `webstreamr` | 23 extractors + 21 sources |
| `scrapers` | Knaben/TPB/Uindex HTML parsers |
| `torrent` | librqbit session (desktop FFI) |
| `proxy` | local HTTP proxy (axum) |
