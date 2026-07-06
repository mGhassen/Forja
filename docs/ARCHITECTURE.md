# Forja — architecture

Technical architecture reference for the Forja engine and monorepo.

**Status:** v1.0 shipped on macOS. **Phase 2 playback complete** — [Phase 3 catalog](migration/03-engine-catalog.md) active.

**Companion docs:** [DEVELOPMENT.md](DEVELOPMENT.md) (build/run) · [features/README.md](features/README.md) (user guide) · [INVENTORY.md](INVENTORY.md) (as-built facts) · [ENGINE_BOUNDARY.md](ENGINE_BOUNDARY.md) (boundary decisions) · [migration/README.md](migration/README.md) (phases) · [RFC-009](rfc/009-rust-ffi.md) (FFI spec)

---

## 1. System overview

Forja is a **GPL-2.0 melos monorepo**: one cross-platform Flutter product (`apps/forja`) backed by a Rust engine (`crates/*`) exposed through FFI. It is a fat-client media hub — movies/TV, IPTV, music, manga, comics, audiobooks, torrents, Stremio addons, Jellyfin, and more.

**Core principle** ([ENGINE_BOUNDARY.md](ENGINE_BOUNDARY.md)):

> **Engine in `crates/*`. Flutter host shows pixels and platform capabilities.**

| Concern | Owner |
|---------|-------|
| Engine (playback, catalog, storage, proxy, scrape) | `crates/*` |
| Legacy engine (`packages/api`, etc.) | Transitional — port to `crates/*` |
| WebView, Nuvio, WASM, player, OAuth | Host (`apps/forja`) |
| Widgets, navigation, theme | Host (`apps/forja`) |
| FFI bridge | `packages/rust` (permanent) |

### Target end-state

```mermaid
flowchart TB
  subgraph host [Host]
    Flutter["apps/forja Flutter permanent"]
  end
  subgraph bridge [FFI bridge]
    DartFFI["packages/rust C ABI"]
  end
  subgraph engine [Engine crates/*]
    FFICrate["crates/ffi libffi"]
    Domain["utils stream-core iptv-core stremio-core webstreamr scrapers torrent proxy storage catalog"]
    FFICrate --> Domain
  end
  Flutter --> DartFFI --> FFICrate
```

Normalized end state: only `packages/rust` under `packages/`. All engine logic in `crates/*`.

### Layer cake (current)

```
┌─────────────────────────────────────┐
│  apps/forja — widgets, nav, player  │
├─────────────────────────────────────┤
│  packages/{api, rust}               │  ← api catalog transitional (wave 2)
├─────────────────────────────────────┤
│  packages/rust — Engine FFI    │
├─────────────────────────────────────┤
│  libffi — c_api + stateful engines  │
├─────────────────────────────────────┤
│  domain crates — parsers, torrent,  │
│  proxy, storage, webstreamr, …      │
└─────────────────────────────────────┘
```

---

## 2. Monorepo topology

```
Forja/
├── apps/forja/          Flutter product (permanent host)
├── packages/
│   ├── rust/            Dart FFI bridge + host prefs (permanent)
│   ├── kotlin/          UniFFI POC (delete wave 2)
│   └── api/             Legacy catalog engine + lib/playback/ (wave 2 deletes catalog)
├── crates/              Rust engine workspace
├── docs/                Architecture, migration, RFCs
└── scripts/             build_rust.sh, build_rust_mobile.sh, …
```

| Path | Role | Fate |
|------|------|------|
| `apps/forja` | Flutter UI + platform host | **Permanent** |
| `packages/rust` | Dart FFI bridge + parity tests | **Permanent** |
| `packages/kotlin` | UniFFI POC (Compose cancelled) | Delete wave 2 |
| `packages/{core,storage,streaming}` | Legacy playback engine | **Deleted** (wave 1) |
| `packages/api` | Legacy catalog engine | Delete wave 2 |
| `crates/*` | Rust engine | **Permanent** |

### Dependency rules

From [RFC-001](rfc/001-monorepo.md):

```
apps/forja → packages/* only
packages/* → never import apps/forja
api → rust
apps/forja → api, rust (Nuvio host in app)
```

Cross-feature navigation uses `shell/app_router.dart` and `shell/shell_bus.dart` — features must not import other features' screens directly.

---

## 3. Rust engine

There is no separate `engine` crate. The engine is the aggregate of domain crates wired through `crates/ffi`, built as **`libffi`** (`cdylib` + `staticlib`).

Default features on `ffi`: `torrent-engine`, `local-proxy`.

### 3.1 Crate map

Workspace members (`crates/Cargo.toml`):

| Crate | Modules / responsibility | Sync vs async | FFI exposure |
|-------|-------------------------|---------------|--------------|
| **`ffi`** | UDL + `c_api.rs` + `engine_proxy` + `engine_torrent` | mixed | all public API |
| **`utils`** | `episode_matcher`, `torrent_filter`, `js_unpacker`, `hls_parser`, `kisskh_subtitle`, `openssl_crypt` | sync | `*_json`, primitives |
| **`stream-core`** | Provider URL templates (VidLink, VixSrc, Vidnest, …) | sync | template builders |
| **`iptv-core`** | M3U parse, Xtream JSON, paste.sh decrypt | sync | parse fns |
| **`stremio-core`** | Manifest/catalog/meta/streams parse + HTTP GET | blocking reqwest | `stremio_*_json` |
| **`webstreamr`** | 23 extractors + 21 sources | sync parsers | granular + `get_streams_json` |
| **`scrapers`** | Knaben / TPB / Uindex HTML → torrent results | async `search_all` | `search_torrents_json` |
| **`torrent`** | librqbit session + localhost axum stream server | tokio | `torrent_*` |
| **`proxy`** | axum localhost relay (generic, HLS rewrite, token routes) | tokio | `proxy_*` |
| **`storage`** | JSON file-backed KV | sync | `storage_*_json` |

Vendored patch: `crates/third_party/librqbit-dualstack-sockets` — iOS socket binding fix for librqbit.

### 3.2 Crate layering inside `ffi`

```mermaid
flowchart TB
  subgraph ffi_crate [crates/ffi]
    UDL[forja.udl]
  LIB[lib.rs wrappers]
    CAPI[c_api.rs C exports]
    EP[engine_proxy.rs]
    ET[engine_torrent.rs]
    UDL --> LIB
    LIB --> CAPI
    LIB --> EP
    LIB --> ET
  end

  subgraph domain [Domain crates]
    U[utils]
    SC[stream-core]
    IPTV[iptv-core]
    STR[stremio-core]
    WS[webstreamr]
    SCR[scrapers]
    TOR[torrent]
    PRX[proxy]
    STO[storage]
  end

  LIB --> U & SC & IPTV & STR & WS & SCR & STO
  ET --> TOR
  EP --> PRX
```

Entry point:

```1:27:crates/ffi/src/lib.rs
mod c_api;
#[cfg(feature = "torrent-engine")]
mod engine_torrent;
#[cfg(feature = "local-proxy")]
mod engine_proxy;

use iptv_core::m3u;
use iptv_core::pastesh;
use scrapers::{dedup_by_infohash, parse_knaben_html, parse_tpb_html, parse_uindex_html, search_all};
use stream_core::list_providers;
use stremio_core::{
    build_resource_url, fetch_get, parse_catalog, parse_manifest, parse_meta, parse_streams,
    parse_subtitles,
};
use utils::{
    episode_matcher, hls_parser, js_unpacker, kisskh_subtitle, torrent_filter,
};
use std::sync::LazyLock;
use tokio::runtime::Runtime;

uniffi::include_scaffolding!("forja");

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[allow(dead_code)]
static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("ffi tokio runtime"));
```

Pattern: `fn foo(...) -> String { domain_crate::foo(...) }` with JSON serialization at the FFI edge. Business logic stays in pure domain crates; `ffi` is glue.

### 3.3 FFI boundary — dual surface, one binary

Two FFI paths load the same `libffi` artifact:

| Path | Contract | Consumer | Status |
|------|----------|----------|--------|
| **C ABI** | `crates/ffi/src/c_api.rs` — `#[no_mangle] extern "C" ffi_*` | `packages/rust` (`RustLib` + `Engine`) | **Active** |
| **UniFFI** | `crates/ffi/src/forja.udl` — POC only | `packages/kotlin/generated/` | Delete wave 2 (P3-00) |

Dart does **not** use UniFFI. The C ABI and UDL must be kept in sync manually.

#### Marshaling contract

| Type | Convention |
|------|------------|
| Primitives | Direct (`i64`, `bool`, `i32`) |
| Complex data | **JSON strings** both ways |
| String memory | `CString::into_raw` out; `ffi_free_string` to release |
| Errors | Embedded in JSON `{"error":"..."}` or sentinels (`"null"`, `-1`) |
| Async Rust | Global `LazyLock<Runtime>` in `ffi`; `block_on` from FFI threads |

#### Dart call chain

```
App → Engine.init() → RustLib.init()
  → DynamicLibrary.open("libffi...")
  → lookup("ffi_*") → call → _readString() → ffi_free_string()
```

Load paths (`packages/rust/lib/src/library_path.dart`):

- Android: `libffi.so` (jniLibs)
- iOS/macOS: `libffi.dylib` (app bundle Frameworks)
- Desktop dev: `crates/target/release/libffi.{dylib,so,dll}`
- Override: `RUST_LIB` env

### 3.4 Stateful subsystems

Long-lived localhost axum servers run **inside** the `libffi` process — not separate OS processes.

| Subsystem | Rust module | Localhost routes | Lifecycle FFI |
|-----------|-------------|------------------|---------------|
| Torrent engine | `engine_torrent.rs` → `torrent` | `GET /torrents/{id}/stream/{file_id}/{*filename}` | `torrent_engine_start` / `stop` |
| Local proxy | `engine_proxy.rs` → `proxy` | `/health`, `/proxy`, `/hls-proxy`, `/proxy/{token}` | `proxy_start` / `stop` / `register_route` |

Both subsystems use internal tokio runtimes. The torrent crate runs its own runtime separate from `ffi`'s `RUNTIME`.

#### Proxy route map

```mermaid
flowchart LR
  Player[media_kit player]
  Proxy["LocalProxy axum\n127.0.0.1:P"]

  subgraph routes [Routes]
    Health["/health"]
    Generic["/proxy?url=&headers="]
    HLS["/hls-proxy?url="]
    Token["/proxy/{token}"]
  end

  Player --> Proxy
  Proxy --> Health
  Proxy --> Generic
  Proxy --> HLS
  Proxy --> Token
  Generic --> Upstream[Upstream CDN]
  HLS --> Upstream
  Token --> Upstream
```

| Route | Purpose |
|-------|---------|
| `/health` | Liveness check |
| `/proxy?url=&headers=` | Generic upstream fetch — CORS bypass, Range, custom headers |
| `/hls-proxy` | HLS playlist rewrite + PNG-wrapper TS strip |
| `/proxy/{token}` | Pre-registered upstream URL by token (`proxy_register_route`) |

Dart registers token routes, then points the player at `http://127.0.0.1:{port}/proxy/{token}`.

---

## 4. Data flows

### 4.1 Torrent playback

```mermaid
sequenceDiagram
  participant UI as Flutter Player
  participant FE as Engine
  participant TOR as crates/torrent
  participant AX as localhost axum
  participant RK as librqbit
  UI->>FE: torrentEngineStart(port)
  UI->>FE: torrentStreamJson(magnet, S, E)
  FE->>TOR: add magnet + episode_matcher
  TOR->>AX: register stream route
  FE-->>UI: JSON url http://127.0.0.1:P/torrents/...
  UI->>AX: GET stream bytes
  AX->>RK: read piece
  RK-->>AX: bytes
  AX-->>UI: video stream
```

1. `TorrentStreamService` starts the engine on a free port.
2. `torrentStreamJson` adds the magnet, `utils::episode_matcher` picks the file for S/E.
3. Returns a localhost URL; media_kit never talks to librqbit directly.

### 4.2 Web stream resolution

**Main path (WebStreamr):** `WebStreamrService` builds a JSON request from settings, then one FFI call — `webstreamrGetStreamsJson`. Rust (`crates/webstreamr`) fetches pages via `fetcher.rs` and runs the full source/extractor pipeline. Dart only post-processes URLs (e.g. 1shows.app HLS re-proxy).

```mermaid
flowchart TD
  UI[Flutter UI]
  WSS[WebStreamrService]
  FE[Engine]
  WS[crates/webstreamr]
  PRX[crates/proxy]
  MK[media_kit]

  UI --> WSS
  WSS -->|request JSON| FE
  FE -->|webstreamr_get_streams_json| WS
  WS -->|fetch + parse in Rust| WS
  WS -->|JSON stream URLs| FE
  FE --> WSS
  WSS --> UI
  UI -->|CORS/headers needed| PRX
  PRX --> MK
  UI -->|direct URL| MK
```

**Legacy / granular FFI:** `extract_embed_html_json`, `parse_webstreamr_source_html_json`, etc. accept pre-fetched HTML (Pattern A in [INVENTORY.md](INVENTORY.md)). The app’s primary WebStreamr path does not use these for full resolve.

**Embed providers (videasy, vidsrc, template):** Mix of Rust (`resolveVidsrcEmbedJson`, template URLs) and host-side WebView/WASM where required — see [INVENTORY.md](INVENTORY.md) §5.

### 4.3 Provider registry resolve

From [RFC-004](rfc/004-provider-registry.md). Registry: `packages/api/lib/playback/provider_registry.dart`.

```mermaid
flowchart TD
  Settings[SettingsService\nprovider order + enabled]
  Resolver[StreamResolver.resolve]
  Template[Template providers\nstream-core via FFI]
  Extractor[Extractor providers\nwebstreamr / vidsrc chain]
  Stremio[Stremio addon streams\nseparate path]
  Result[ResolvedStream]

  Settings --> Resolver
  Resolver --> Template
  Template -->|fail| Extractor
  Extractor -->|fail| Stremio
  Template -->|success| Result
  Extractor -->|success| Result
  Stremio -->|success| Result
```

`getActiveProviders()` respects user order. `resolve(movie, season, episode)` tries providers sequentially; first success wins. Stremio addon streams are separate from the built-in provider grid.

### 4.4 Storage / prefs

```
Engine.init(storagePath)
  → storage_open(path)           # crates/storage JSON KV
  → kv.dart prefers Rust KV when engine ready
  → one-time SharedPreferences migration in facade.dart
```

Host prefs (`SettingsService`, `kv.dart`, watch history) live in **`packages/rust/lib/src/`** after wave 1.

---

## 5. Legacy engine packages (transitional)

See [ENGINE_BOUNDARY.md](ENGINE_BOUNDARY.md). All engine logic targets `crates/*`.

| Package | Wave | Status |
|---------|------|--------|
| `packages/streaming` | 1 | **Deleted** — playback in `api/lib/playback/`, Nuvio in app |
| `packages/storage` | 1 | **Deleted** — prefs in `packages/rust` |
| `packages/core` | 1 | **Deleted** — DTOs in `api/models/` |
| `packages/api` | 2 | Catalog + playback glue — catalog port wave 2 |

Deleted (engine in Rust): `packages/scrapers`, `packages/webstreamr`, legacy `packages/forja_*`, `streaming`, `storage`, `core`.

### Package dependency graph (post wave 1)

```mermaid
flowchart BT
  rust[rust]
  api[api] --> rust
  app["apps/forja"] --> api & rust
```

### What survives in `packages/` (normalized)

| Package | Role | Fate |
|---------|------|------|
| `packages/rust` | Dart FFI bridge + parity tests | **Permanent** |

---

## 6. Flutter UI (minimal)

The UI layer is intentionally simple — no Riverpod, Bloc, or go_router.

| Layer | Path | Role |
|-------|------|------|
| Bootstrap | `apps/forja/lib/app/bootstrap.dart` | Platform init, `Engine.init()`, service warm-up, splash |
| Shell | `apps/forja/lib/shell/` | `MainScreen` tab map, `AppRouter`, `ShellBus`, `nav_config` |
| Features | `apps/forja/lib/features/` | One folder per nav tab (~20 verticals) |
| Shared | `apps/forja/lib/shared/` | Player (`media_kit`), design tokens, casting stubs |

**State:** `StatefulWidget` + `setState`, singleton services (`SettingsService`, `StremioService`, `TorrentStreamService`, …), `ValueNotifier` for theme/nav/search.

**Routing:** `MaterialApp(home: SplashScreen())` — no named routes. Tab switching via `MainScreen` index. Secondary nav via `Navigator.push`. Cross-feature hot paths via `AppRouter.openMovie()` / `openPlayer()`.

**Player:** `shared/player/` → media_kit (custom AimesSoft fork). Defers to `Engine` for torrent re-search, proxy URLs, episode matching. Platform split: `mobile_player_screen.dart` / `desktop_player_screen.dart`.

**Nav tabs (19 + settings):** Home · Discover · Similar · Search · My List · Media Downloader · Magnet · Live Matches · IPTV · Audiobooks · Books · Music · Comics · Manga · Jellyfin · Anime · Anime Arabic · Asian Drama · Arabic · Settings.

---

## 7. Build, artifacts, CI

| Script | Output |
|--------|--------|
| `./scripts/build_rust.sh` | `crates/target/release/libffi.{dylib,so,dll}` |
| `./scripts/build_rust_mobile.sh ios` | `apps/forja/ios/Runner/Frameworks/libffi.dylib` |
| `./scripts/build_rust_mobile.sh android` | `apps/forja/android/app/src/main/jniLibs/arm64-v8a/libffi.so` |
| `./scripts/build_macos.sh` | `apps/forja/build/macos/.../forja.app` |
| `./scripts/generate_kotlin_ffi.sh` | `packages/kotlin/generated/` |

| Melos command | What |
|---------------|------|
| `melos run rust:build` | Desktop Rust engine |
| `melos run rust:build:mobile` | iOS + Android FFI |
| `melos run rust:test` | `cargo test` + Dart parity |
| `melos run rust:integration` | App engine smoke (desktop) |

### Artifact locations

| Platform | Path |
|----------|------|
| Desktop dev | `crates/target/release/libffi.*` |
| macOS bundle | `apps/forja/macos/Runner/Frameworks/libffi.dylib` |
| Android | `jniLibs/arm64-v8a/libffi.so` |
| iOS | `ios/Runner/Frameworks/libffi.dylib` |

### CI workflows

| Workflow | Trigger |
|----------|---------|
| `.github/workflows/rust.yml` | PR touching `crates/**` or `packages/rust/**` |
| `.github/workflows/forja-macos.yml` | macOS releases |
| `.github/workflows/build.yml` | General build |

### Tests

| Layer | Location | Command |
|-------|----------|---------|
| Rust unit + golden | `crates/*/src`, `crates/*/tests/` | `cargo test --workspace` |
| Dart ↔ Rust parity | `packages/rust/test/parity/` | `cd packages/rust && flutter test` |
| App smoke | `apps/forja/test/engine_smoke_test.dart` | `melos run rust:integration` |

Parity rule: Rust output must match Dart reference for the same fixture before switching a call site.

---

## 8. Migration delta (engine lens)

See [02-rust-engine-complete.md](migration/02-rust-engine-complete.md) and [ENGINE_BOUNDARY.md](ENGINE_BOUNDARY.md).

### Wave 1 — playback engine (Phase 2)

| Status | Items |
|--------|-------|
| Done | scrapers, webstreamr, forja_*, torrent filter, HLS proxy, *Backend removed, streaming/storage/core delete, Stremio/IPTV HTTP, proxy consolidate |
| Open | IPTV catalog scraper (wave 2) |

### Wave 2 — catalog engine (Phase 3)

`packages/api` verticals → `crates/*`; delete `packages/api` and `packages/kotlin`.

### Wave 1 exit gate

[Playback engine exit checklist](migration/02-rust-engine-complete.md#playback-engine-exit-checklist) — app shippable; starts wave 2.

### Architecture complete

[03-engine-catalog.md exit checklist](migration/03-engine-catalog.md#exit-checklist) — only `packages/rust` remains.

---

## 9. Design decisions and constraints

| Decision | Rationale |
|----------|-----------|
| **Two layers: engine vs host** | All non-platform logic in `crates/*`; Flutter for UI + platform ([ENGINE_BOUNDARY](ENGINE_BOUNDARY.md)) |
| **JSON as FFI IPC** | Simplicity over zero-copy |
| **C ABI via `packages/rust`** | Permanent Dart FFI bridge |
| **FFI Pattern B default** | fetch+parse in Rust; Pattern A (`*_html_json`) legacy only |
| **No sync FFI on UI thread** | Long resolve → `Isolate.run` (P2-91) |
| **Host orchestration** | Provider race UX in UI; Rust owns pipelines (webstreamr, torrent search) |
| **WebView / Nuvio / player host-only** | Platform capabilities — never Rust |
| **Network is not the boundary** | HTTP location is implementation detail inside engine |
| **Long-lived localhost axum** | Torrent + proxy inside `libffi` |
| **Thin FFI, fat domain** | Logic in pure crates |

### Anti-patterns

- Dart wrapper calling Rust instead of deleting Dart
- Sync FFI on UI thread for resolve/search
- New Pattern A FFI for engine work
- New engine logic in Dart
- `*Backend` hooks (removed P2-86)

### Allowed

- Host provider race + loading/cancel UX
- Legacy `packages/api` during wave 2 only — no new Dart engine logic
- `Isolate.run` for long FFI calls

---

## 10. Cross-references

| Doc | Purpose |
|-----|---------|
| [INVENTORY.md](INVENTORY.md) | As-built codebase inventory (facts only) |
| [ENGINE_BOUNDARY.md](ENGINE_BOUNDARY.md) | Host vs engine boundary (locked) |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Build, run, melos scripts |
| [crates/README.md](../crates/README.md) | Rust build, NDK, iOS patch |
| [migration/README.md](migration/README.md) | Migration phases 1–4 |
| [migration/02-rust-engine-complete.md](migration/02-rust-engine-complete.md) | Active phase task tracker |
| [rfc/001-monorepo.md](rfc/001-monorepo.md) | Monorepo layout, dependency rules |
| [rfc/004-provider-registry.md](rfc/004-provider-registry.md) | Stream provider registry |
| [rfc/009-rust-ffi.md](rfc/009-rust-ffi.md) | Rust FFI spec |
| [rfc/011-v1.0-mvp.md](rfc/011-v1.0-mvp.md) | v1.0 scope |
