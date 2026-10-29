# Forja App

Main Flutter product - permanent UI host. Engine: [Phase 2 playback wave](../../docs/migration/fixed/02-[fixed]-rust-engine-complete.md) · [Phase 3 catalog wave](../../docs/migration/fixed/03-[fixed]-engine-catalog.md).

## Run (desktop)

Rust engine must be built once before the first run:

```bash
# from repo root
./scripts/build_rust.sh
# or: melos run rust:build

cd apps/forja
flutter pub get
flutter run -d macos
```

Boot log should show `[Engine] Rust engine v1.2.67` (or current `[workspace.package] version` in `crates/Cargo.toml`). If you see `Rust engine NOT loaded`, re-run `build_rust.sh` or set `RUST_LIB` to the release dylib path. Set `RUST_STRICT=1` to fail fast in debug when the library is missing.

## Run (mobile)

```bash
./scripts/build_rust_mobile.sh all   # or android / ios
cd apps/forja && flutter run          # iOS; Android needs --flavor (below)
```

Mobile FFI ships full engine (parsers + librqbit torrent + proxy). Magnet playback uses Rust/librqbit via FFI.

### Android (NDK)

Release APK bundles Rust automatically (`buildRust=true`). Debug needs a manual build or env flag:

```bash
./scripts/build_rust_mobile.sh android          # optional pre-build
BUILD_RUST_ANDROID=1 flutter run -d android --flavor mobile   # phone / tablet
BUILD_RUST_ANDROID=1 flutter run -d android --flavor tv       # Android TV
flutter build apk --flavor mobile   # release - builds Rust via pre<Flavor>ReleaseBuild
```

Android has two product flavors (`formFactor` dimension): `tv` and `mobile`. `--flavor` is required on every Android run/build. Both share `com.forjahq.app` and the signing key, so one replaces the other in place.

See [crates/README.md](../../crates/README.md) for NDK discovery details.

## Tests

```bash
melos run rust:test                              # Rust + Dart parity
cd apps/forja && flutter test test/engine_smoke_test.dart  # engine smoke (desktop)
```

## Layout

- `lib/app/` - bootstrap
- `lib/shell/` - nav, `AppRouter`, `ShellBus`
- `lib/features/` - one folder per nav tab
- `lib/shared/` - player, widgets, casting/sync stubs
