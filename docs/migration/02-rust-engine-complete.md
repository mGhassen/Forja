# Phase 2 — Rust engine complete

**Status:** In progress  
**Depends on:** [Phase 1 complete](./01-rust-engine.md)  
**Next phase:** [Phase 3 — Kotlin Compose UI](./03-kotlin-compose.md)  
**Migration index:** [README.md](./README.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

---

## Architecture (locked — do not forget)

```
UI (Flutter Phase 2 · Compose Phase 3)
  → widgets, navigation, player chrome ONLY
  → calls engine FFI, renders JSON

Rust engine (crates/* + libffi)
  → EVERYTHING that is not pixels
```

| **Engine (Rust)** | **UI (Dart/Kotlin)** |
|-------------------|----------------------|
| HTTP fetch | Widgets |
| Parse, crypto, extract | Navigation |
| Torrent (librqbit) | Player surface (media_kit / ExoPlayer) |
| Storage (prefs, history, settings) | Theme application |
| External APIs (TMDB, Trakt, Stremio, debrid, …) | WebView **host** (not extract logic) |
| Scraper / webstreamr / stream resolve pipelines | Error/loading states |
| Proxy (HLS rewrite) | |

**These Dart packages are ENGINE — must move to Rust or die in Phase 2/4, not “UI”:**

| Package | Engine content |
|---------|----------------|
| `packages/api` | TMDB, Trakt, debrid, scrapers, extractors, subtitles, … |
| `packages/storage` | Prefs, watch history, provider/IPTV settings |
| `packages/core` | Models = engine DTOs (from Rust JSON) |
| `packages/scrapers` | Torrent search (→ Rust P2-81) |
| `packages/webstreamr` | Stream source pipeline (→ Rust P2-82) |
| `packages/streaming` | Resolver, torrent service (→ Rust P2-83+) |
| `packages/rust` | FFI loader only until Phase 4 |

**Anti-patterns (delete, do not add):**
- `*Backend` static hooks — engine split across two languages
- `rust_delegates.dart` — replace with direct FFI (P2-86)
- Dart `compute()` calling engine hooks — isolates don't see statics
- Calling “orchestration OK in Dart until Phase 3” — **wrong**; engine finishes in Phase 2

**Phase 3** = swap Flutter UI for Compose. **Same Rust engine.** No logic port to Kotlin.  
**Phase 4** = delete Flutter + all Dart packages. Keep `packages/kotlin` + `crates/`.

---

## Status at a glance

**Goal:** Rust owns the **entire engine**. Flutter is **UI only**.

| | |
|--|--|
| **Progress** | **22 / 36 tasks done (61%)** |
| **Blocks Phase 3** | P2-80 tail · P2-82/83/85 pipelines · P2-88/89 (api/storage) |
| **Also open** | B2 mobile smoke · JNI proof · sign-off |

**Legend:** ✅ done · 🔄 partial · ⬜ not started

### Task tracker

#### ✅ Finished

| IDs | What |
|-----|------|
| P2-20 → P2-23 | Drop libtorrent |
| P2-30 → P2-33 | Strip Dart HTML parse fallbacks |
| P2-60 → P2-63 | Delete legacy `packages/forja_*` |
| P2-12, P2-13, P2-15 | Mobile torrent wiring |
| P2-50, P2-51 | uniffi UDL + Kotlin bindgen scaffold |
| **P2-81** | Scraper pipeline → `search_torrents_json` |
| **P2-84** | Torrent filter → `filter_torrents_json` |
| **P2-87** | Dead Dart scraper files deleted (`packages/scrapers` = aggregator only) |
| **P2-86** | All `*Backend` hooks removed; direct FFI everywhere |

#### 🔄 In progress — B2 mobile

| ID | Done | Left |
|----|------|------|
| P2-10 | iOS compile | Android NDK |
| P2-14 | Desktop magnet E2E | iOS + Android device |

#### ⬜ Todo — engine pipelines (blocks Phase 3)

| ID | What |
|----|------|
| P2-80 | Document + expand high-level FFI surface |
| P2-82 | Webstreamr pipeline → Rust |
| P2-83 | Stream resolver → Rust |
| P2-85 | Proxy → Rust only (drop shelf engine routes) |
| P2-87 | Delete gutted Dart engine packages (scrapers ✅; webstreamr/streaming/api remain) |
| **P2-88** | **`packages/storage` → `crates/storage` + FFI** |
| **P2-89** | **`packages/api` → Rust crates (TMDB, Trakt, debrid, …)** |
| **P2-90** | **`packages/core` models → generated from engine JSON** |

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
| 6 | Scraper search via `search_torrents_json` (no shelf hop) | ✅ P2-81 |
| 7 | Torrent filter via `filter_torrents_json` | ✅ P2-84 |
| 8 | Magnet → stream mobile | ⬜ P2-14 |
| 9 | All pipelines in Rust (webstreamr, resolver, proxy) | ⬜ P2-82–85 |
| 10 | **`packages/api` + `packages/storage` in Rust** | ⬜ P2-88/89 |
| 11 | No `*Backend` hooks | ✅ P2-86 |
| 12 | Sign-off | ⬜ P2-70 |

**Phase 3 starts when #9 + #10 + #11 are ✅.**

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
  P2_81["P2-81 scrapers"]
  P2_82["P2-82 webstreamr"]
  P2_88["P2-88 storage"]
  P2_89["P2-89 api"]
  P2_86["P2-86 kill hooks"]
  P3["Phase3 UI only"]

  P2_81 --> P2_82 --> P2_88 --> P2_89 --> P2_86 --> P3
```

---

## Related

- [Phase 1](./01-rust-engine.md) · [Phase 3 UI](./03-kotlin-compose.md) · [RFC-009](../rfc/009-rust-ffi.md)
