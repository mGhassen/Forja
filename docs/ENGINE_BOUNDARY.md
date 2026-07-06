# Forja — engine boundary

Canonical rules for what lives in **Rust (`crates/*`)**, the **host app** (Flutter / Compose), or **FFI loaders only** (`packages/rust`, `packages/kotlin`).

**Status:** Locked (2026-07-06). Grounded in [INVENTORY.md](INVENTORY.md).

**Migration execution:** [migration/README.md](migration/README.md) · [Phase 2 tasks](migration/02-rust-engine-complete.md)

---

## 1. Engine tiers

| Tier | Definition | Phase gate |
|------|------------|------------|
| **Tier-1** | Playback path — title selected → playable URL in player | Must be Rust before Phase 3 |
| **Tier-2** | Catalog/metadata APIs (TMDB, verticals) | May stay in host packages; freeze — no new Dart logic |
| **Host-only** | Platform capabilities (R3) | Never Rust |

---

## 2. Locked decisions

| ID | Choice |
|----|--------|
| **D1** | **C** — Rust core + incremental tier-2 crates |
| **D2** | **C** — Hybrid orchestration: Rust pipelines; host provider race + loading UX |
| **D3** | **A** — Nuvio permanent host (C4) |
| **D4** | **B** — Jackett/Prowlarr optional host plugins; Knaben in Rust |
| **D5** | **A** — OAuth/secrets host-only; Rust receives tokens per call when needed |
| **D6** | **A** — Consolidate loopback servers into `crates/proxy` (P2-92) |
| **D7** | **A** — Move `app_theme` to `apps/forja` (P2-96) |
| **D8** | **A** — New FFI: fetch+parse in Rust; deprecate HTML-in shims |
| **D9** | Phased package deletion — see §7 |

**Webstreamr:** Keep `crates/webstreamr` (no Dart rollback). UI freeze fixed via isolate offload (P2-91), not language change. See [issue 001](issues/001-webstreamr-blocks-ui.md).

---

## 3. Capability taxonomy

| ID | Class | Examples | Platform required? |
|----|-------|----------|-------------------|
| **C1** | REST/JSON/GraphQL | TMDB, Trakt, Jellyfin | No — tier-2 |
| **C2** | HTML/XML scrape + parse | manga, Knaben (Rust) | No |
| **C3** | WebView embed sniff | `stream_extractor`, kisskh | **Yes** — host |
| **C4** | JS runtime (non-browser) | Nuvio `flutter_js` | **Yes** — host |
| **C5** | WASM host | Videasy extractor | **Yes** — host |
| **C6** | Video/audio decode | media_kit, audio_service | **Yes** — host |
| **C7** | Local loopback HTTP | proxy, shelf, 111477 | No — tier-1 → Rust |
| **C8** | Crypto/transform | openssl_crypt, AES | No — tier-1 |
| **C9** | Persistence | prefs, history | Tier-1 in Rust KV; secrets on host |
| **C10** | UI | theme, widgets, nav | **Yes** — host |
| **C11** | Orchestration | provider races, subtitles | Split — see R6 |
| **C12** | OAuth / OS intents | Trakt OAuth, VLC | **Yes** — host |

---

## 4. Rules

### R1 — Tier-1 (must be Rust before Phase 3)

Playback path: title selected → playable URL in player.

- `crates/webstreamr`, `torrent`, `proxy`, `scrapers`, `stream-core`, `stremio-core` (fetch+parse unified — P2-93)
- `site111477` proxy + index (P2-83)
- `crates/storage` typed prefs/history (P2-88)
- Stateless transforms: `utils`, `iptv-core` parsers; IPTV HTTP unified (P2-94)
- Consolidated local HTTP (P2-92)

### R2 — Tier-2 (host until opportunistic Rust port)

Catalog/metadata verticals (C1): TMDB, Trakt, Jellyfin, anime, manga, music, Arabic, etc.

- May remain in `packages/api` through early Phase 3 (P2-89b)
- **No new engine logic in Dart** — freeze; port when touching a vertical
- Compose may bridge to remaining `packages/api` temporarily or port vertical to Rust per screen

### R3 — Host-only (never Rust)

| Class | Examples |
|-------|----------|
| C3 | WebView extractors |
| C4 | Nuvio `flutter_js` |
| C5 | Videasy WASM host |
| C6 | media_kit, audio_service, PiP, external player |
| C10 | Theme, widgets, navigation |
| C12 | OAuth flows, secure storage, OS intents |

### R4 — Network is not the boundary

HTTP in Rust or host is an implementation choice. The split line is **tier-1 playback path** vs **host capabilities** (R2–R3).

### R5 — FFI

- Default: **fetch+parse in Rust** (Pattern B)
- **Forbidden:** sync FFI on UI thread for calls expected to exceed ~50ms — use `Isolate.run` ([P2-91](issues/001-webstreamr-blocks-ui.md))
- **Deprecated:** Pattern A (`*_html_json` HTML-in) for new tier-1 work
- Exception: Pattern A OK when host already holds HTML from an active WebView session (C3)

### R6 — Orchestration (C11)

- **Rust:** cohesive pipelines with golden tests — webstreamr, vidsrc chain, torrent search
- **Host:** provider order, loading/cancel UX, subtitle aggregation
- Delete unused `StreamResolver`, dead storage repos, duplicate `stream_extractor` (P2-95)

### R7 — App feature folders

Engine logic in `apps/forja/features/**/data/` must move to the same destination as equivalent package code (tier-1 → Rust, tier-2 → freeze/port, host → app). IPTV HTTP is tier-1 (P2-94).

---

## 5. Package deletion (D9)

| Package | Phase 2 | Phase 3 / 4 |
|---------|---------|-------------|
| `streaming` | Delete after P2-83, 91, 92 | — |
| `storage` | Delete after P2-88 (+ P2-96 theme → app) | — |
| `core` | Delete after P2-90 | — |
| `api` | Shrink — tier-1 slices out; freeze tier-2 | Delete when Compose screens ported (P2-89b) |
| `webstreamr` | Deleted — logic in `crates/webstreamr` (no rollback) | — |
| `rust` | — | Delete Phase 4 |
| `kotlin` | — | **Permanent** |

---

## 6. What survives in `packages/`

| Package | Fate |
|---------|------|
| `packages/rust` | FFI loader until Phase 4 — no logic |
| `packages/kotlin` | Generated UniFFI bindings — permanent |
| `packages/api` | Tier-2 transitional — delete Phase 3/4 |
| Others | Delete per §5 |

---

## 7. Evidence (from inventory)

| Fact | Implication |
|------|-------------|
| Rust ~8.5k LOC; Dart api ~23.7k LOC | Tier-2 port is large — not a Phase 2 gate |
| Four localhost server patterns | Consolidate in P2-92 |
| FFI Pattern A + B coexist | Standardize on B for tier-1 |
| WebView ~1.9k, player ~1.8k, REST ~17k | Boundary by capability class, not package name |
| Engine in `apps/forja/features/iptv/` | R7 — package delete ≠ engine complete |

---

## Related

| Doc | Role |
|-----|------|
| [INVENTORY.md](INVENTORY.md) | As-built facts |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Target architecture |
| [migration/README.md](migration/README.md) | Phase plan |
| [RFC-009](rfc/009-rust-ffi.md) | FFI spec |
