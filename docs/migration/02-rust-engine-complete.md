# Phase 2 — Rust engine complete

**Status:** In progress  
**Depends on:** [Phase 1 complete](./01-rust-engine.md)  
**Next phase:** [Phase 3 — Kotlin Compose UI](./03-kotlin-compose.md)  
**Migration index:** [README.md](./README.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

---

## Migration rule (locked — no negotiation)

**Move = rewrite in Rust `crates/*`, expose FFI, delete the Dart package.**

| Step | Action |
|------|--------|
| 1 | Port Dart engine logic → Rust crate |
| 2 | Add FFI in `crates/ffi` / uniffi |
| 3 | UI calls `Engine.*` directly |
| 4 | **Delete the Dart package** — directory, deps, imports |

### Only these `packages/` survive

| Package | Purpose |
|---------|---------|
| `packages/rust` | Dart FFI loader (deleted Phase 4 with Flutter) |
| `packages/kotlin` | uniffi bindings for Compose (permanent) |

### These `packages/` must be rewritten in Rust and deleted

| Dart package | Rust crate(s) | Task |
|--------------|---------------|------|
| `packages/api` | tmdb, debrid, stremio, … | P2-89 |
| `packages/storage` | `crates/storage` | P2-88 |
| `packages/core` | engine JSON / codegen | P2-90 |
| `packages/scrapers` | `crates/scrapers` | P2-81 / P2-87 |
| `packages/webstreamr` | `crates/webstreamr` | P2-82 |
| `packages/streaming` | `crates/streaming`, `crates/proxy`, … | P2-83 |

**A task is not done until the Dart package (or its engine files) is deleted.**

---

## Architecture

```
UI (apps/forja — Flutter Phase 2 · Compose Phase 3)
  → widgets, navigation, player chrome ONLY
  → calls Engine / kotlin FFI, renders JSON

Rust engine (crates/* + libffi)
  → EVERYTHING that is not pixels
```

| **Rust engine** | **UI only** |
|-----------------|-------------|
| HTTP fetch, external APIs | Widgets |
| Parse, crypto, extract | Navigation |
| Torrent (librqbit) | Player surface |
| Storage, prefs, history | Theme |
| Scraper / webstreamr / resolver | WebView host |
| Proxy (HLS rewrite) | Error/loading states |

**Anti-patterns (never do these):**
- Dart wrapper calling Rust (`EngineStorage`, thin repos) — **delete the Dart file instead**
- “Backend swap” — SharedPreferences → Rust KV while keeping Dart package alive
- `*Backend` static hooks — engine split across two languages
- `rust_delegates.dart` — direct FFI only (P2-86 ✅)
- Dart `compute()` calling engine — isolates don't see statics
- “Orchestration OK in Dart until Phase 3” — **wrong**
- Leaving a Dart package as “facade until Phase 4” — **wrong**; Phase 2 deletes engine Dart

**Phase 3** = swap Flutter UI for Compose. Same Rust engine. No logic port to Kotlin.  
**Phase 4** = delete `apps/forja` + `packages/rust`. Keep `packages/kotlin` + `crates/*`.

---

## Status at a glance

**Goal:** every engine package lives in `crates/*`; zero engine Dart under `packages/`.

| | |
|--|--|
| **Progress** | **28 / 36 tasks done (78%)** — `scrapers` + `webstreamr` + `ffi_*` deleted |
| **Blocks Phase 3** | P2-83/87/88/89/90 — Dart engine packages still exist |
| **Also open** | B2 mobile smoke · JNI proof · sign-off |

**Legend:** ✅ done · 🔄 partial · ⬜ not started

### Task tracker

#### ✅ Finished

| IDs | What |
|-----|------|
| P2-20 → P2-23 | Drop libtorrent |
| P2-30 → P2-33 | Strip Dart HTML parse fallbacks |
| **P2-87** | `packages/scrapers` **deleted**; search via `Engine.searchTorrents` only |
| **P2-60** | Legacy `packages/forja_*` **deleted** (7 orphan packages removed) |
| P2-12, P2-13, P2-15 | Mobile torrent wiring |
| P2-50, P2-51 | uniffi UDL + Kotlin bindgen scaffold |
| **P2-81** | Scraper pipeline → `search_torrents_json`; dead scraper files deleted |
| **P2-84** | Torrent filter → `filter_torrents_json`; Dart filter logic deleted |
| **P2-86** | All `*Backend` hooks removed; direct FFI everywhere |
| **P2-85** | HLS proxy in Rust; Dart HLS rewrite deleted from `local_server_service.dart` |
| **P2-82** | `packages/webstreamr` **deleted**; full resolve via `ffi_webstreamr_get_streams_json` |

#### 🔄 Partial — not done until Dart package deleted

| ID | Rust done | Dart still alive (must delete) |
|----|-----------|--------------------------------|
| **P2-83** | vidsrc 3-hop (`ffi_resolve_vidsrc_embed_json`), webstreamr service, videasy OpenSSL AES (`ffi_openssl_aes_decrypt_json`), provider URL dedup | **`packages/streaming`** — videasy WASM, nuvio JS runtime, site111477 seekable proxy (~1.5k LOC), `local_server_service` shelf routes |
| **P2-88** | `crates/storage` KV + FFI; `Engine` storage facade + legacy prefs migration | **`packages/storage`** — `kv.dart` glue, `app_theme.dart`, repos still thin wrappers |
| **P2-85** | HLS + proxy forward | Jellyfin/toky/comic shelf routes in Dart |

#### 🔄 In progress — B2 mobile

| ID | Done | Left |
|----|------|------|
| P2-10 | iOS compile | Android NDK |
| P2-14 | Desktop magnet E2E | iOS + Android device |

#### ⬜ Todo — port to Rust + delete Dart (blocks Phase 3)

| ID | Dart package to delete | Rust work |
|----|------------------------|-----------|
| P2-80 | — | Document + expand FFI surface |
| **P2-83** | **`packages/streaming`** (engine parts) | site111477 seekable proxy, nuvio host glue; videasy HTTP loop optional |
| **P2-88** | **`packages/storage`** | Typed settings/history APIs; delete all Dart storage |
| **P2-89** | **`packages/api`** | TMDB, Trakt, debrid, jackett, subtitles, … |
| **P2-90** | **`packages/core`** (engine models) | JSON from Rust; UI uses maps/codegen |

#### ⬜ Todo — sign-off

| ID | What |
|----|------|
| P2-11 | Android NDK CI |
| P2-52 | JNI packaging proof |
| P2-70 → P2-72 | Smoke · RFC · README gate |

### Exit checklist

| # | Criterion | |
|---|-----------|---|
| 1 | `libtorrent_flutter` removed | ✅ |
| 2 | Dart HTML parse fallbacks removed | ✅ |
| 3 | Parse/crypto/torrent primitives in Rust | ✅ |
| 4 | Legacy `packages/forja_*` deleted | ✅ |
| 5 | Magnet → stream desktop | ✅ |
| 6 | `packages/scrapers` deleted | ✅ P2-87 |
| 7 | Torrent filter via Rust; Dart deleted | ✅ P2-84 |
| 8 | Magnet → stream mobile | ⬜ P2-14 |
| 9 | `packages/webstreamr` deleted; `packages/streaming` engine deleted | 🔄 P2-82 ✅ · P2-83 partial |
| 10 | **`packages/api` + `packages/storage` + `packages/core` deleted** | ⬜ P2-88/89/90 |
| 11 | No `*Backend` hooks | ✅ P2-86 |
| 12 | Only `packages/rust` + `packages/kotlin` remain under `packages/` (plus no engine code in `apps/forja/lib`) | ⬜ |
| 13 | Sign-off | ⬜ P2-70 |

**Phase 3 starts when #6–#12 are ✅.**

---

## Quick health check

```bash
./scripts/build_rust.sh
cd crates && cargo test --workspace
melos run rust:test && melos run rust:integration
```

---

## Dependency chain

```mermaid
flowchart LR
  P2_81["P2-81 scrapers → delete"]
  P2_82["P2-82 webstreamr → delete"]
  P2_88["P2-88 storage → delete"]
  P2_89["P2-89 api → delete"]
  P2_90["P2-90 core → delete"]
  P3["Phase3 UI only"]

  P2_81 --> P2_82 --> P2_88 --> P2_89 --> P2_90 --> P3
```

---

## Related

- [Phase 1](./01-rust-engine.md) · [Phase 3 UI](./03-kotlin-compose.md) · [RFC-009](../rfc/009-rust-ffi.md)
