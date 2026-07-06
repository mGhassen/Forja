# Forja — engine boundary (draft)

Framework for deciding what lives in **Rust (`crates/*`)**, the **host app** (Flutter / Compose), or **FFI loaders only** (`packages/rust`, `packages/kotlin`).

**Status:** Draft — decisions pending. Grounded in [INVENTORY.md](INVENTORY.md) (as-built facts).

**Not the same as:** [migration/README.md](migration/README.md) (phase plan — states packages must be deleted; does not define technical boundary per capability class).

---

## 1. Purpose

Before writing locked rules, agree on:

1. What the codebase **actually contains** (see inventory).
2. Which **technology classes** have hard platform requirements.
3. Which **open product/architecture choices** only you can make.

This doc records (2) as observed facts and (3) as a decision checklist. **Section 5** holds rule slots — fill after decisions.

---

## 2. Evidence summary (from inventory)

| Fact | Implication for boundary work |
|------|------------------------------|
| Rust ~8.5k LOC; Dart api alone ~23.7k LOC | Engine port surface is large; not all of it is stream-resolution |
| Four localhost server implementations | Consolidation is a design task, not implied by "move to Rust" |
| FFI has fetch+parse and parse-only APIs | Pick one pattern per capability when porting |
| ~8 app files call Rust directly; ~50 import api | Today the app talks to Dart services, not FFI |
| WebView ~1.9k LOC, player ~1.8k LOC, REST ~17k LOC | Three different stacks; boundary should be by capability class |
| Engine logic in `apps/forja/features/iptv/` | Package deletion ≠ engine complete unless app features are in scope |
| Dead code: `StreamResolver`, 3 storage repos, streaming `stream_extractor` | Cleanup opportunity independent of boundary rules |

---

## 3. Capability classes (taxonomy)

Use these labels when assigning ownership — not package names.

| ID | Class | Examples in repo | Platform runtime required? |
|----|-------|------------------|---------------------------|
| **C1** | REST/JSON/GraphQL client | TMDB, Trakt, debrid, Jellyfin | No |
| **C2** | HTML/XML scrape + parse | manga, arabic, bestsimilar, Knaben (Rust) | No |
| **C3** | WebView embed sniff | `stream_extractor`, kisskh, amri, comics | **Yes** — browser/DOM/JS |
| **C4** | JS runtime (non-browser) | Nuvio `flutter_js` + cheerio | **Yes** — JS VM |
| **C5** | WASM host | Videasy extractor | **Yes** — WASM runtime |
| **C6** | Video/audio decode + UI chrome | media_kit, audio_service, PiP | **Yes** — OS decoder/surface |
| **C7** | Local loopback HTTP | Rust proxy, shelf, 111477, mega_proxy | No |
| **C8** | Crypto/transform (stateless) | openssl_crypt, AllAnime AES, mega decrypt | No |
| **C9** | Persistence (prefs, history) | kv, watch history, settings | Partial — secure tokens need keychain |
| **C10** | UI (theme, widgets, nav) | `app_theme`, shell, features | **Yes** — UI toolkit |
| **C11** | Orchestration (multi-step resolve) | `StreamResolver`, player provider races, subtitle_api | No — but product choice where it lives |
| **C12** | OAuth / external intents | Trakt OAuth, VLC launch | **Yes** — OS integration |

---

## 4. Open decisions

Check one option per row when ready. Rules in §5 depend on these.

### D1 — Engine shape

| Option | Description |
|--------|-------------|
| **A** | Monolithic `crates/*` — TMDB, Trakt, all verticals become Rust crates |
| **B** | Rust **core** (stream/torrent/proxy/storage) + host adapters per vertical |
| **C** | Rust core + optional Rust plugins/crates added incrementally |

**Inventory note:** Rust today covers ~movie/TV resolve path only; option A is largest port (~17k+ LOC REST).

---

### D2 — Orchestration location (C11)

| Option | Description |
|--------|-------------|
| **A** | Rust: single FFI e.g. `resolve_movie_json` reads settings internally |
| **B** | Host: UI calls granular FFI steps in sequence |
| **C** | Hybrid: Rust for stream grid; host for vertical-specific flows |

**Inventory note:** `StreamResolver` exists but is unused; player screens orchestrate inline today.

---

### D3 — Nuvio (C4)

| Option | Description |
|--------|-------------|
| **A** | Permanent host concern — keep JS scraper ecosystem on flutter_js / Compose equivalent |
| **B** | Port to Rust JS runtime (e.g. rquickjs) — scrapers unchanged |
| **C** | Deprecate Nuvio — rely on webstreamr/rust only |

**Inventory note:** ~1.9k LOC (`nuvio_runtime` + `nuvio_service`); HTTP bridged from Dart today.

---

### D4 — Jackett / Prowlarr vs Knaben scrapers

| Option | Description |
|--------|-------------|
| **A** | Port Jackett/Prowlarr to Rust; unify with `search_torrents_json` |
| **B** | Keep as optional Dart/host indexer plugins |
| **C** | Rust Knaben only; drop Jackett/Prowlarr |

**Inventory note:** Two parallel torrent indexer systems today.

---

### D5 — OAuth / secure storage (C9, C12)

| Option | Description |
|--------|-------------|
| **A** | Host-only — Rust never touches keychain; tokens passed per FFI call |
| **B** | Rust engine stores secrets via platform FFI bridge |
| **C** | Split — API keys in Rust KV file; OAuth tokens on host |

**Inventory note:** `flutter_secure_storage` in api; Rust KV for non-secret prefs.

---

### D6 — Localhost servers (C7)

| Option | Description |
|--------|-------------|
| **A** | One Rust proxy — migrate shelf + 111477 + mega routes into `crates/proxy` |
| **B** | Rust generic/HLS only; domain routes stay host-side |
| **C** | Status quo until Compose |

**Inventory note:** Four patterns today (see INVENTORY §5).

---

### D7 — Theme / UI in storage (C10)

| Option | Description |
|--------|-------------|
| **A** | Move `app_theme.dart` to `apps/forja` now |
| **B** | Wait for Compose; delete with `packages/storage` |
| **C** | Keep until storage package deleted |

**Inventory note:** 331 LOC Flutter UI inside engine package.

---

### D8 — FFI fetch vs parse-only

| Option | Description |
|--------|-------------|
| **A** | New APIs: always fetch+parse in Rust (deprecate HTML-in FFI) |
| **B** | Keep both — host fetches when it already has a WebView session |
| **C** | Case-by-case |

**Inventory note:** Stremio, IPTV, HLS still split; webstreamr main path already unified.

---

### D9 — Package deletion vs destination

Migration says delete `packages/{api,core,storage,streaming}`. When deleted, contents go to:

| Package | Rust crate(s) | Host app | Eliminate |
|---------|---------------|----------|-----------|
| `api` | _TBD per D1_ | C3, C6, C12 slices | dead code |
| `streaming` | proxy extensions, 111477? | C3, C4, C5, C7 slices | thin FFI wrappers |
| `storage` | `crates/storage` typed API | C10 (`app_theme`) | kv glue, dead repos |
| `core` | JSON types / codegen | C10 utils | DTOs as maps? |

Fill after D1–D8.

---

## 5. Rule slots (fill after decisions)

### R1 — Default ownership

> **TBD.** Candidate form: "Capability classes C1, C2, C7, C8, C9 (non-secret), C11 default to Rust unless D_ says otherwise."

### R2 — Host-only classes

> **TBD.** Candidate form: "C3, C6, C10, C12 are host-only. C4/C5 per D3."

### R3 — Network boundary

> **TBD.** Inventory shows network I/O is not a useful split line — Rust already owns HTTP in multiple crates. Rule should **not** say "network stays in host."

### R4 — FFI shape

> **TBD.** Per D8.

### R5 — App feature folders

> **TBD.** e.g. "Engine logic in `apps/forja/features/**/data/` must move to same destination as equivalent package code."

### R6 — What survives in `packages/`

| Package | Current plan (migration) | Boundary rule |
|---------|-------------------------|---------------|
| `packages/rust` | Delete Phase 4 | FFI loader, no logic |
| `packages/kotlin` | Permanent | Generated bindings, no logic |
| Others | Delete Phase 2 | **TBD** destination per D9 |

---

## 6. Suggested rule-writing order

1. Decide **D3, D5, D7** (hard platform classes — smallest debate).
2. Decide **D8** (FFI pattern — affects every port).
3. Decide **D1** (engine shape — scopes P2-89).
4. Decide **D2, D6** (orchestration + servers).
5. Decide **D4** (indexers).
6. Write **R1–R6** in this file; update [ARCHITECTURE.md](ARCHITECTURE.md) target section.
7. Update migration task breakdown if D1/D9 change scope.

---

## Related

| Doc | Role |
|-----|------|
| [INVENTORY.md](INVENTORY.md) | As-built facts |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Target architecture (update after rules locked) |
| [migration/README.md](migration/README.md) | Phase execution |
