# Phase 2 — Rust engine complete

**Status:** In progress  
**Depends on:** [Phase 1 complete](./01-rust-engine.md)  
**Next phase:** [Phase 3 — Kotlin Compose UI](./03-kotlin-compose.md)  
**Migration index:** [README.md](./README.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

---

## Status at a glance

**Goal:** Rust owns the **entire engine** (fetch, route, parse, torrent). Flutter is **UI only** — call engine, render JSON.

| | |
|--|--|
| **Progress** | **17 / 32 tasks done (53%)** |
| **Blocks Phase 3** | **P2-80 → P2-87** (0 / 8 done) — move pipelines into Rust, kill `*Backend` hooks |
| **Also open** | B2 mobile smoke (2 tasks) · JNI proof (1) · sign-off (3) |

**Legend:** ✅ done · 🔄 started, not finished · ⬜ not started

### Task tracker

#### ✅ Finished — no action needed

| IDs | What |
|-----|------|
| P2-20 → P2-23 | Drop `libtorrent_flutter` — pubspecs, torrent service, call sites, cleanup |
| P2-30 → P2-33 | Strip Dart HTML parse fallbacks (webstreamr, registry, scrapers) |
| P2-60 → P2-63 | Delete legacy `packages/forja_*` copies |
| P2-12 | Mobile build script defaults to full Rust features |
| P2-13 | Torrent wired on mobile (same path as desktop) |
| P2-15 | `applyConnectionsLimit` → librqbit `peer_limit` |
| P2-50 | `forja.udl` expanded |
| P2-51 | uniffi Kotlin bindgen scaffold |

#### 🔄 In progress — B2 mobile librqbit

| ID | What | Done | Left |
|----|------|------|------|
| P2-10 | librqbit builds on mobile | iOS compiles (vendored patch) | Android NDK verify |
| P2-14 | Magnet → HTTP stream E2E | Desktop | iOS + Android device |

#### ⬜ Todo — B2 tail

| ID | What |
|----|------|
| P2-11 | Android NDK full-features build in CI |

#### ⬜ Todo — **blocks Phase 3** (P2-80 engine pipelines)

| ID | What | Replaces today |
|----|------|----------------|
| P2-80 | Design high-level FFI (one call per user action) | scattered `*Backend` hooks |
| P2-81 | Scraper pipeline → Rust (HTTP + parse + dedup) | `ScraperAggregator` in Dart |
| P2-82 | Webstreamr pipeline → Rust (fetch + source loop) | `WebStreamrService` in Dart |
| P2-83 | Stream resolver → Rust (provider loop) | `stream_resolver.dart` |
| P2-84 | Torrent filter → Rust (pre-filtered JSON to UI) | `torrent_filter.dart` hooks |
| P2-85 | HLS/proxy → Rust only | `local_server_service.dart` engine routes |
| P2-86 | Delete `*Backend` hooks + `rust_delegates.dart` | 15+ static hooks |
| P2-87 | Gut/delete `packages/scrapers`, `webstreamr`, engine bits of `streaming`/`api` | thin Dart engine packages |

#### ⬜ Todo — after P2-80

| ID | What |
|----|------|
| P2-52 | JNI packaging proof (reuse mobile `.so` / `.dylib`) |
| P2-70 | Manual smoke — every user flow = one FFI call |
| P2-71 | RFC-009 Step 9 checked off |
| P2-72 | Mark Phase 2 complete in README → unlock Phase 3 |

### Exit checklist

| # | Criterion | |
|---|-----------|---|
| 1 | `libtorrent_flutter` removed | ✅ |
| 2 | Dart HTML parse fallbacks removed | ✅ |
| 3 | Parse/crypto/torrent primitives in Rust only | ✅ |
| 4 | Legacy `packages/forja_*` deleted | ✅ |
| 5 | Magnet → stream on **desktop** | ✅ |
| 6 | Magnet → stream on **mobile** (iOS + Android) | ⬜ P2-14 |
| 7 | Mobile FFI full features build (iOS + Android) | 🔄 P2-10/11 |
| 8 | **Engine pipelines in Rust** (fetch + route + filter + resolve) | ⬜ P2-80 → P2-87 |
| 9 | **UI calls engine only** — no `*Backend` hooks | ⬜ P2-86 |
| 10 | uniffi POC + JNI proof | 🔄 P2-50/51 ✅ · P2-52 ⬜ |
| 11 | Sign-off smoke + RFC + README gate | ⬜ P2-70 → P2-72 |

**6 / 11 exit criteria met.** Phase 3 starts when **#8 + #9** are ✅.

### What's left in Dart (must become ⬜ after P2-80)

| Today (wrong) | Fix |
|---------------|-----|
| Scraper HTTP fetch + aggregator | P2-81 |
| Webstreamr fetch + registry loop | P2-82 |
| Stream provider loop | P2-83 |
| Torrent title filter orchestration | P2-84 |
| Shelf HLS/proxy routes | P2-85 |
| `rust_delegates.dart` hook wiring | P2-86 |

### Quick health check

```bash
./scripts/try_build_mobile_torrent.sh ios
./scripts/build_rust_mobile.sh all
cd crates && cargo test --workspace
melos run rust:test && melos run rust:integration
```

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
