# Phase 2 — Rust engine complete

**Status:** In progress  
**Depends on:** [Phase 1 complete](./01-rust-engine.md)  
**Next phase:** [Phase 3 — Kotlin Compose UI](./03-kotlin-compose.md)  
**Migration index:** [README.md](./README.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

---

## Status at a glance

**Goal:** Rust owns the **entire engine** — fetch, route, parse, crypto, torrent, filter, resolve. Flutter is **UI only**: call engine, render results. No engine work in Dart.

**Phase 2 in progress.** Parse/crypto/torrent primitives are in Rust; **pipelines still leak into Dart** (see [Current gaps](#current-gaps)). Do not start Phase 3 until P2-80 workstream is done.

### Architecture (locked)

```
┌─────────────────────────────────────┐
│  UI (Phase 2: Flutter · Phase 3: Compose)   │
│  widgets · nav · player surface only        │
└─────────────────┬───────────────────┘
                  │ FFI (JSON in/out)
┌─────────────────▼───────────────────┐
│  Rust engine (crates/* + libffi)    │
│  HTTP · routing · parse · torrent   │
└─────────────────────────────────────┘
```

| Layer | Owns | Does NOT own |
|-------|------|--------------|
| **Rust** | Every user-facing engine operation end-to-end | Widgets, platform WebView host, ExoPlayer/AVPlayer |
| **UI (Dart/Kotlin)** | Display engine responses, navigation, player chrome | HTTP fetch for scrapers/webstreamr, provider loops, `*Backend` hooks, shelf proxy logic |

**Anti-patterns (delete in Phase 2, not Phase 3):**
- `ScraperParseBackend`, `WebstreamrParseBackend`, `TorrentFilterBackend`, … — engine split across two languages
- `rust_delegates.dart` wiring 15+ static hooks — replace with direct FFI / uniffi calls from UI layer
- `compute()` / isolates calling engine hooks — engine calls stay on main thread or inside Rust

### Three columns — read every table this way

| Column | Question |
|--------|----------|
| **Rust** | Full pipeline in `crates/` + exposed via FFI? |
| **App** | UI calls engine API and renders JSON — no Dart/Kotlin engine logic? |
| **Dart removed** | Old fetch/route/filter/hook code deleted? |

**Done = ✅** when Rust implements the pipeline **and** UI only displays the result.

### Workstreams

| Workstream | Done | Target | Status |
|------------|-----:|-------:|--------|
| B2 — mobile librqbit | 4 | 6 | iOS compile done · device smoke + Android NDK open |
| Drop libtorrent | 4 | 4 | **done** |
| Strip Dart parse fallbacks | 4 | 4 | **done** |
| Legacy engine purge | 4 | 4 | **done** |
| **P2-80 engine pipelines** | 0 | 8 | **open — blocks Phase 3** |
| Kotlin FFI prep | 2 | 3 | P2-50/51 **done** · P2-52 JNI proof open |
| Sign-off | 0 | 3 | P2-70 · P2-71 · P2-72 |

### Feature matrix

| Area | Rust pipeline | UI only | Dart engine removed | Notes |
|------|:-------------:|:-------:|:-------------------:|-------|
| Parse/crypto/torrent primitives | ✅ | ✅ | ✅ | FFI fns exist; hooks wire them |
| B2 — mobile librqbit | ✅ iOS | partial | N/A | mobile device + Android NDK open |
| Drop libtorrent | ✅ | ✅ | ✅ | |
| Dart HTML parse fallbacks | ✅ | ✅ | ✅ | |
| **Scraper search pipeline** | partial | ❌ | partial | Rust parses HTML; **Dart still HTTP + aggregator** |
| **Webstreamr resolve pipeline** | partial | ❌ | partial | Rust extracts; **Dart still fetch + registry loop** |
| **Stream provider resolver** | partial | ❌ | partial | Rust templates; **Dart still provider loop** |
| **Torrent filter pipeline** | partial | ❌ | partial | Rust parseSceneInfo; **Dart still filter orchestration** |
| **Local HLS/proxy** | partial | ❌ | partial | Rust proxy exists; **Dart shelf still routes** |
| Kill `*Backend` hooks | — | — | ❌ | P2-86 open |

### Exit criteria

| Criterion | Status |
|-----------|--------|
| Mobile FFI full features (iOS/Android) | open |
| Magnet → HTTP stream on mobile | open |
| Magnet → HTTP stream on desktop | ✅ |
| `libtorrent_flutter` removed | ✅ |
| Dart HTML parse fallbacks removed | ✅ |
| Parse/crypto/torrent in Rust only (no Dart fallbacks) | ✅ |
| **Engine pipelines in Rust (fetch + route + filter + resolve)** | **open (P2-80)** |
| **UI calls engine only — no `*Backend` hooks** | **open (P2-86)** |
| **`packages/{scrapers,webstreamr,streaming}` engine code deleted** | **open (P2-87)** |
| Legacy `packages/forja_*` deleted | ✅ |
| RFC-009 Step 9 + uniffi POC | partial |

### What UI may do (Flutter now, Compose in Phase 3)

| Allowed | Examples |
|---------|----------|
| Call `ForjaEngine` / uniffi generated API | `engine.searchTorrents(title)` → render list |
| Bind JSON to widgets | torrent rows, stream URLs, errors |
| Platform surfaces | WebView container, media_kit player, PiP |
| App prefs / theme / nav | `storage`, settings screens |

| Forbidden in UI layer | Where it wrongly lives today |
|-----------------------|------------------------------|
| HTTP fetch for engine ops | `packages/scrapers`, `packages/webstreamr` |
| Provider / source routing loops | `stream_resolver.dart`, `WebStreamrService` |
| Torrent title filter logic | `torrent_filter.dart` (beyond display sort) |
| Static `*Backend` hook wiring | `rust_delegates.dart`, `*_parse.dart` |
| Shelf proxy engine routes | `local_server_service.dart` |

### Numbers

| Metric | Value |
|--------|-------|
| Exit criteria met | 6 / 11 |
| P2-80 pipeline tasks | 0 / 8 |
| B2 tasks done | 4 / 6 |

### Quick health check

```bash
./scripts/try_build_mobile_torrent.sh ios
./scripts/build_rust_mobile.sh all
cd crates && cargo test --workspace
melos run rust:test && melos run rust:integration
```

### Next work

1. **P2-80** — move engine pipelines into Rust (blocks Phase 3)
2. **P2-14** — magnet E2E on iOS/Android device
3. **P2-11** — Android NDK full-features build

---

## Torrent engine decision (locked)

**Decision:** keep **librqbit** (rqbit) as the only torrent engine.

| Option | Verdict |
|--------|---------|
| **librqbit** (`crates/torrent`) | **Ship.** |
| **libtorrent_flutter** | **Removed** (P2-20/21) |

Probe: `./scripts/try_build_mobile_torrent.sh ios`  
Files: `crates/torrent/`

---

## Current gaps

| Gap | Today | Phase 2 fix |
|-----|-------|-------------|
| Scraper search | Dart HTTP → Rust parse | P2-81 — full pipeline in Rust |
| Webstreamr | Dart fetch/registry → Rust extract | P2-82 |
| Stream resolve | Dart provider loop | P2-83 |
| Torrent filter on details | Dart filter + Rust parse via hooks | P2-84 |
| HLS/proxy | Dart shelf + Rust proxy split | P2-85 |
| 15+ `*Backend` static hooks | `rust_delegates.dart` | P2-86 |
| Mobile librqbit device smoke | open | P2-14 |

---

## Tasks

### B2 — Mobile librqbit

| ID | Task | Status |
|----|------|--------|
| P2-10 | Fix librqbit iOS/Android build | iOS **done** |
| P2-11 | Android NDK CI | open |
| P2-12 | Full features in mobile build | **done** |
| P2-13 | Wire torrent on mobile | **done** |
| P2-14 | Magnet E2E on device | partial (desktop E2E ✅) |
| P2-15 | `applyConnectionsLimit` → librqbit | **done** |

### Drop libtorrent — **done**

P2-20 through P2-23 complete.

### Strip Dart parse fallbacks — **done**

P2-30 through P2-33, P2-62, P2-64 (parse layer) complete.

### P2-80 — Engine owns pipelines (**blocks Phase 3**)

| ID | Task | Detail |
|----|------|--------|
| P2-80 | Design high-level FFI surface | One call per user action: e.g. `search_torrents_json(query)`, `resolve_stream_json(provider, tmdb, s, e)`, `filter_torrents_json(results, title, s, e)` |
| P2-81 | Scraper pipeline → Rust | HTTP + knaben/tpb/uindex + dedup in `crates/scrapers`; delete `ScraperAggregator` fetch/parse path |
| P2-82 | Webstreamr pipeline → Rust | Fetch + source loop in `crates/webstreamr`; delete Dart `WebStreamrService` engine path |
| P2-83 | Stream resolver → Rust | Provider loop + template resolve in `crates/stream_core` |
| P2-84 | Torrent filter → Rust | Title filter in `crates/utils` or `crates/scrapers`; UI gets pre-filtered JSON |
| P2-85 | Proxy → Rust only | HLS rewrite in `crates/proxy`; remove engine routes from `local_server_service.dart` |
| P2-86 | Delete `*Backend` hooks | Remove `rust_delegates.dart`; UI → `ForjaEngine` / uniffi only |
| P2-87 | Delete thin Dart engine packages | Remove or gut `packages/scrapers`, `webstreamr`, engine parts of `streaming`/`api` |

### Legacy purge — **done**

P2-60 through P2-63 complete.

### Kotlin FFI prep

| ID | Task | Status |
|----|------|--------|
| P2-50 | Expand `forja.udl` | **done** |
| P2-51 | uniffi Kotlin bindgen | **done** |
| P2-52 | JNI packaging proof | open |

### Sign-off

| ID | Task | Detail |
|----|------|--------|
| P2-70 | Manual smoke | **Engine:** magnet E2E, stream resolve, scraper search via FFI. **UI:** screens render engine JSON / errors — no `*Backend not wired` |
| P2-71 | Update RFC-009 | Mark Step 9 + B2 + P2-80 complete |
| P2-72 | Mark Phase 2 complete in README | Gate Phase 3 |

**Do not start Phase 3 until P2-80 + P2-86 are done.** Phase 3 replaces Flutter UI with Compose — **same Rust engine**, zero orchestration port.

---

## Dependency chain

```mermaid
flowchart LR
  P2_10["P2-10 librqbit mobile"]
  P2_20["P2-20 drop libtorrent"]
  P2_30["P2-30 strip parse fallbacks"]
  P2_80["P2-80 engine pipelines"]
  P2_86["P2-86 kill Backend hooks"]
  P3["Phase3 Compose UI only"]

  P2_10 --> P2_20 --> P2_30 --> P2_80 --> P2_86 --> P3
```

---

## Acceptance checklist

- [x] `./scripts/try_build_mobile_torrent.sh ios` passes
- [ ] `./scripts/build_rust_mobile.sh all` (Android NDK)
- [x] Zero `libtorrent_flutter` in active packages
- [x] Zero Dart HTML parse fallbacks
- [x] Parse/crypto/torrent primitives in Rust
- [ ] **Engine pipelines in Rust (P2-80)**
- [ ] **No `*Backend` hooks in app (P2-86)**
- [ ] `melos run rust:test` + integration green
- [ ] Release APK/IPA magnet via librqbit

---

## Manual testing (Phase 2)

**Engine (Rust)** — the real gate:
- `cargo test --workspace`, parity tests, magnet E2E
- After P2-80: each user flow = one FFI call; test that call directly

**UI (Flutter)** — minimal:
- Boot → engine loads (log line, no init errors)
- Tap action → loading state → list/stream/error from engine response
- Never test "Dart orchestration" — there shouldn't be any

---

## Related

- [Phase 1 — Rust engine](./01-rust-engine.md)
- [Phase 3 — Kotlin Compose UI](./03-kotlin-compose.md)
- [RFC-009](../rfc/009-rust-ffi.md)
