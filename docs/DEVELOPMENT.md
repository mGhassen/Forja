# Forja — development

Technical guide for building, running, and contributing to Forja.

**Status:** v1.0 shipped on macOS. Active work: [Phase 2 — Rust engine complete](migration/02-rust-engine-complete.md).

---

## Architecture

Full system architecture: [ARCHITECTURE.md](ARCHITECTURE.md).

Forja is a **melos monorepo**:

| Layer | Location | Role |
|-------|----------|------|
| **UI** | `apps/forja` | Flutter app — transitional; deleted in Phase 4 |
| **FFI loader** | `packages/rust` | Thin Dart bindings to `libffi` |
| **Engine** | `crates/*` | Rust — parsers, crypto, extractors, torrent (librqbit), proxy |
| **Orchestration** | `packages/*` | Dart services (HTTP, registry, shelf) — deleted in Phase 2 |

```
apps/forja (Flutter UI)
    └── packages/rust (FFI)
            └── crates/ffi → utils, webstreamr, iptv-core, torrent, proxy, …
```

End-state: Kotlin Compose UI + Rust engine. See [migration/README.md](migration/README.md).

---

## Repository layout

```
Forja/
├── apps/forja/              Flutter product
│   ├── lib/app/             Bootstrap, ForjaEngine init
│   ├── lib/shell/           MainScreen, AppRouter, nav (19 tabs)
│   ├── lib/features/        One folder per nav tab
│   └── lib/shared/          Player, widgets, casting/sync stubs
├── packages/
│   ├── core/                Models, utilities (deleted Phase 2)
│   ├── storage/             Settings, persistence, theme (deleted Phase 2)
│   ├── api/                 TMDB, Trakt, Stremio, Jellyfin (deleted Phase 2)
│   ├── streaming/           Torrent session, providers, proxy glue (deleted Phase 2)
│   ├── rust/                Dart FFI + parity tests (deleted Phase 4)
│   └── kotlin/              UniFFI bindings (permanent)
├── crates/                  Rust engine — ffi, utils, webstreamr, scrapers, torrent, proxy, …
├── docs/migration/          Phases 1–5
├── docs/rfc/                Design specs
└── scripts/                 build_rust.sh, build_rust_mobile.sh, build_macos.sh
```

Nav tabs: Home · Discover · Similar · Search · My List · Media Downloader · Magnet · Live Matches · IPTV · Audiobooks · Books · Music · Comics · Manga · Jellyfin · Anime · Anime Arabic · Asian Drama · Arabic · Settings.

---

## Prerequisites

- **Flutter** 3.11+ ([flutter.dev](https://flutter.dev))
- **Rust** stable + cargo ([rustup.rs](https://rustup.rs))
- **melos** — `dart pub global activate melos`
- **Desktop:** Xcode (macOS), VS Build Tools (Windows), GTK dev libs (Linux)
- **Android:** NDK r26+ (Android Studio SDK Manager)
- **iOS:** macOS + Xcode

---

## Quick start

```bash
git clone https://github.com/forja/forja.git && cd forja
melos bootstrap

./scripts/build_rust.sh          # required before first run

cd apps/forja
flutter pub get
flutter run -d macos             # or windows / linux / android / ios
```

Boot log must show `[ForjaEngine] Rust engine v0.1.0`. If you see `Rust engine NOT loaded`:

- Re-run `./scripts/build_rust.sh`
- Or set `FORJA_RUST_LIB` to the release dylib path
- Debug: `FORJA_RUST_STRICT=1` fails fast when the library is missing

---

## Build by platform

### Desktop

```bash
./scripts/build_rust.sh              # or: melos run rust:build
cd apps/forja && flutter run -d macos
```

Release macOS:

```bash
./scripts/build_macos.sh             # → apps/forja/build/macos/.../forja.app
```

### Mobile

```bash
./scripts/build_rust_mobile.sh all   # ios + android arm64
cd apps/forja && flutter run
```

Mobile FFI ships the full engine (parsers + librqbit torrent + proxy).

**Android debug:**

```bash
./scripts/build_rust_mobile.sh android
FORJA_BUILD_RUST_ANDROID=1 flutter run -d android
```

**Android release** — Rust bundles automatically:

```bash
flutter build apk
```

**iOS** — Release/Profile builds compile Rust via Xcode phase. Debug: run `build_rust_mobile.sh ios` once first.

More detail: [apps/forja/README.md](../apps/forja/README.md) · [crates/README.md](../crates/README.md)

---

## Melos scripts

| Command | What |
|---------|------|
| `melos bootstrap` | Pub get all packages |
| `melos run rust:build` | Desktop Rust engine |
| `melos run rust:build:mobile` | iOS + Android FFI |
| `melos run rust:test` | `cargo test` + Dart parity |
| `melos run rust:integration` | App engine smoke (desktop) |
| `melos run rust:release-check` | Verify mobile libffi artifacts |
| `melos run analyze` | Flutter analyze |
| `melos run test` | Flutter unit tests |

---

## Testing

```bash
melos run rust:test                              # Rust unit + golden + Dart parity
melos run rust:integration                       # integration_test/ (build Rust first)
cd apps/forja && flutter test integration_test/
```

Parity tests: `packages/rust/test/` — compare `ForjaRust.instance.*` against Dart reference implementations.

---

## Engine workflow

When changing Rust engine code:

1. Read current phase in [migration/README.md](migration/README.md)
2. `./scripts/build_rust.sh` + `cargo test --workspace`
3. `cd packages/rust && flutter test` (parity)
4. Update the active migration doc when a task completes

Agent rules: [`.cursor/rules/rust-migration.mdc`](../.cursor/rules/rust-migration.mdc)

---

## Documentation index

| Doc | Purpose |
|-----|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture, engine, data flows |
| [apps/forja/README.md](../apps/forja/README.md) | App run/build, layout |
| [crates/README.md](../crates/README.md) | Rust crates, NDK, iOS patch |
| [migration/README.md](migration/README.md) | Migration phases 1–5 |
| [rfc/README.md](rfc/README.md) | RFC index |
| [rfc/009-rust-ffi.md](rfc/009-rust-ffi.md) | Engine FFI spec |
| [rfc/011-v1.0-mvp.md](rfc/011-v1.0-mvp.md) | v1.0 scope & checklist |
