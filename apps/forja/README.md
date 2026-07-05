# Forja App

Main Flutter product. See [README_FORJA.md](../../README_FORJA.md) for monorepo layout.

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

Boot log should show `[ForjaEngine] Rust engine v0.1.0`. If you see `Rust engine NOT loaded`, re-run `build_rust.sh` or set `FORJA_RUST_LIB` to the release dylib path. Set `FORJA_RUST_STRICT=1` to fail fast in debug when the library is missing.

## Run (mobile)

```bash
./scripts/build_rust_mobile.sh all   # or android / ios
cd apps/forja && flutter run
```

Mobile FFI ships parsers only (no librqbit); torrent playback uses `libtorrent_flutter`.

## Tests

```bash
melos run rust:test                              # Rust + Dart parity
cd apps/forja && flutter test integration_test/  # engine smoke (desktop)
```

## Layout

- `lib/app/` — bootstrap
- `lib/shell/` — nav, `AppRouter`, `ShellBus`
- `lib/features/` — one folder per nav tab
- `lib/shared/` — player, widgets, Phase 3 stubs (design/casting/sync)
