# Forja — development

Technical guide for building, running, and contributing to Forja.

**Status:** v1.0 shipped on macOS. Engine migration complete — [migration/README.md](migration/README.md) (Phases 1–3 ✅).

---

## Architecture

Full system architecture: [ARCHITECTURE.md](ARCHITECTURE.md). As-built inventory: [INVENTORY.md](INVENTORY.md). **Host vs engine rules:** [ENGINE_BOUNDARY.md](ENGINE_BOUNDARY.md).

Forja is a **melos monorepo**:

| Layer | Location | Role |
|-------|----------|------|
| **UI** | `apps/forja` | Flutter app — permanent host |
| **FFI bridge** | `packages/rust` | Dart bindings to `libffi` |
| **Engine** | `crates/*` | Rust — parsers, crypto, extractors, torrent (librqbit), proxy, catalog |
| **Legacy engine** | `packages/api` (catalog; wave 2) | Port to `crates/*` per [ENGINE_BOUNDARY](ENGINE_BOUNDARY.md) |

```
apps/forja (Flutter host)
    └── packages/rust (FFI bridge)
            └── crates/ffi → utils, webstreamr, iptv, torrent, proxy, catalog, …
```

End-state: Flutter + Rust engine. See [migration/README.md](migration/README.md).

---

## Repository layout

```
Forja/
├── apps/forja/              Flutter product
│   ├── lib/app/             Bootstrap, Engine init
│   ├── lib/shell/           MainScreen, AppRouter, nav (19 tabs)
│   ├── lib/features/        One folder per nav tab
│   └── lib/shared/          Player, widgets, casting/sync stubs
├── packages/
│   ├── rust/                FFI bridge, SettingsService, parity tests (permanent)
│   └── api/                 Catalog + lib/playback/ (catalog ports wave 2)
├── crates/                  Rust engine — ffi, utils, webstreamr, scrapers, torrent, proxy, catalog, …
├── docs/migration/          Engine migration (`fixed/` · `canceled/`)
├── docs/rfc/                RFC specs (`[draft]` / `[open]` / `[partial]` / `fixed/`)
├── docs/backlog/              One file per version (`0.7.6-[open].md` / `done/` / `canceled/`)
├── docs/issues/             Bugs and follow-ups (`[draft]` / `[open]` / `fixed/`)
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

cp .env.example .env             # fill API keys + local/hosted Supabase client config
./scripts/build_rust.sh          # required before first run — bakes .env into libffi

cd apps/forja
flutter pub get
flutter run -d macos --dart-define-from-file=../../.env
```

### API keys / `.env`

Dev secrets live in a **gitignored** repo-root `.env` (see `.env.example`). Rust `build.rs` in `crates/tmdb`, `crates/webstreamr`, and `crates/anime` injects `TMDB_API_KEY`, `TMDB_READ_ACCESS_TOKEN`, and `WYZIE_API_KEY` at **compile time**. After editing `.env`, rebuild Rust (`./scripts/build_rust.sh` or `cargo build -p ffi`).

| Var | Used by |
|-----|---------|
| `TMDB_API_KEY` | Catalog / Home / Search (`crates/tmdb`) |
| `TMDB_READ_ACCESS_TOKEN` | WebStreamr TMDB lookups when Settings token is empty |
| `WYZIE_API_KEY` | Player subtitle search (`crates/anime` Wyzie) |
| `SUPABASE_URL` | Shared Supabase project used by desktop accounts and settings sync |
| `SUPABASE_PUBLISHABLE_KEY` | Public Supabase client key (`sb_publishable_…`); never use `service_role` / `sb_secret_…` in the app |
| `RELEASE_CDN_URL` | Public base URL for release installers on Cloudflare R2 (custom domain or `pub-*.r2.dev`). Built into clients via `--dart-define` / `VITE_RELEASE_CDN_URL`. |
| `R2_ACCOUNT_ID` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | **CI only** — Release workflow uploads installers to R2 bucket `forja-releases` and prunes to the newest 3 versions |
| `FORJA_WEB_URL` | Deployed web portal origin for desktop **Web login** / signup links. Local default `http://127.0.0.1:3000`. **Required** as a GitHub secret for release/build CI (must not be localhost). |
| `TURNSTILE_SITE_KEY` | Cloudflare Turnstile site key for in-app email/password when Auth captcha is on. Local dummy `1x00000000000000000000AA`. Optional GitHub secret for release. |

**Desktop reality:** anything baked into the binary can be extracted. `.env` keeps keys out of git; it does **not** hide them from someone who reverse-engineers a shipped build. Real options for production: a small backend proxy that holds the key, or user-supplied keys (WebStreamr already has a Settings TMDB token). TMDB’s v3 key is rate-limited per key — rotate if it leaks; prefer the read token only where Bearer is needed.

CI / release: repo secrets `TMDB_API_KEY`, `TMDB_READ_ACCESS_TOKEN`, `WYZIE_API_KEY`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (falls back to legacy `SUPABASE_ANON_KEY`), **`R2_ACCOUNT_ID`**, **`R2_ACCESS_KEY_ID`**, **`R2_SECRET_ACCESS_KEY`**, **`RELEASE_CDN_URL`**, **`FORJA_WEB_URL`**, and optional **`TURNSTILE_SITE_KEY`** / **`R2_BUCKET`** / **`R2_ENDPOINT`** are injected by `.github/workflows/{build,release}.yml`. On **forjahq**, optional **`ORIGIN_SYNC_TOKEN`** (fine-grained PAT with Contents write on `mGhassen/Forja`) makes **Release Forja → New version** push the release commit + tag back to origin; optional variable **`ORIGIN_SYNC_REPO`** overrides the default `mGhassen/Forja`. Flutter builds receive Supabase + release CDN + portal URL (+ captcha site key) through `--dart-define`; use the hosted project values in GitHub, never the local `127.0.0.1` URL. Never put R2 access keys in `--dart-define` or Vite env.

**Debug badge:** In debug (`flutter run`), a small runtime **DEV** chip sits under the nav-rail wordmark (`kDebugMode`). macOS also sets a dock badge via `windowManager.setBadgeLabel('DEV')`. No alternate logo assets required.

Boot log must show `[Engine] Rust engine v0.1.0`. If you see `Rust engine NOT loaded`:

- Re-run `./scripts/build_rust.sh`
- Or set `RUST_LIB` to the release dylib path
- Debug: `RUST_STRICT=1` fails fast when the library is missing

---

## Build by platform

### Desktop

```bash
./scripts/build_rust.sh              # or: melos run rust:build
cd apps/forja && flutter run -d macos --dart-define-from-file=../../.env
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
BUILD_RUST_ANDROID=1 flutter run -d android
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
melos run rust:integration                       # test/engine_smoke_test.dart (build Rust first)
cd apps/forja && flutter test test/engine_smoke_test.dart
```

Parity tests: `packages/rust/test/` — compare `RustLib.instance.*` against Dart reference implementations.

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
| [INVENTORY.md](INVENTORY.md) | As-built codebase inventory (facts only) |
| [ENGINE_BOUNDARY.md](ENGINE_BOUNDARY.md) | Host vs engine boundary (locked) |
| [apps/forja/README.md](../apps/forja/README.md) | App run/build, layout |
| [crates/README.md](../crates/README.md) | Rust crates, NDK, iOS patch |
| [migration/README.md](migration/README.md) | Migration phases 1–5 |
| [rfc/README.md](rfc/README.md) | RFC index |
| [rfc/fixed/009-[fixed]-rust-ffi.md](rfc/fixed/009-[fixed]-rust-ffi.md) | Engine FFI spec |
| [rfc/fixed/011-[fixed]-v1.0-mvp.md](rfc/fixed/011-[fixed]-v1.0-mvp.md) | v1.0 scope & checklist |
