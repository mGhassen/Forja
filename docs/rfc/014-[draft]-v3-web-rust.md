# RFC-014: v3.0 — Web client + Rust core

**Version:** v3.0  
**Status:** draft  
**Target version:** v3  
**Depends on:** RFC-013 (optional; v1.0 codebase sufficient to start Rust extraction)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 5** acceptance (v3.0 bundle) |
| **Current slice** | v3.0 — WASM + web client |
| **Backlog** | v3 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v3.0 bundle)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R14-A01 | Rust crates compile; unit tests for IPTV + provider resolution | ⬜ |
| 2 | R14-A02 | Flutter macOS uses FFI for at least one hot path | ⬜ |
| 3 | R14-A03 | Web app loads browse + plays HLS stream | ⬜ |
| 4 | R14-A04 | No libtorrent in web bundle | ⬜ |
| 5 | R14-A05 | Optional Supabase sync on web (RFC-006) | ⬜ |

---

## Goal

Browser-based Forja with shared logic in Rust (native FFI + WASM), HLS-only playback, optional cloud sync backend.

## Deliverables

### 1. Rust core (RFC-009)

Extract to workspace crates:

| Crate | Responsibility |
|-------|----------------|
| `iptv-core` | Xtream protocol, M3U parse, portal crypto |
| `stremio-core` | Addon manifest, catalog deserialize |
| `stream-core` | Provider registry, URL templates (no libtorrent) |

**Flutter:** `dart:ffi` on desktop/mobile.  
**Web:** compile to WASM; JS interop via `wasm_bindgen`.

Keep Dart UI; Rust owns parsing, crypto, and provider resolution hot paths.

### 2. Web client (RFC-010)

```
apps/forja_web/   (or flutter build web from apps/forja with guards)
```

| Capability | Web |
|------------|-----|
| Browse / details | yes |
| HLS/MP4 playback | yes (video element or hls.js) |
| Torrent / libtorrent | **no** |
| IPTV live | HLS-only streams |
| Download / magnet | hidden |
| Sync | RFC-006 backend |

Shared WASM module from Rust crates for IPTV parse + provider templates.

### 3. Monorepo impact

- `packages/streaming` — thin Dart wrapper over Rust on native; WASM on web
- `packages/scrapers` — may stay Dart or move scrape logic to Rust incrementally
- Feature folders unchanged; platform gates via `kIsWeb` / `Platform.is*`


## Related RFCs

RFC-009, RFC-010
