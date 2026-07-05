# Phase 5 — Web client (parallel track)

**Status:** Parallel — does not block Phase 2, 3, or 4  
**Spec:** [RFC-014](../rfc/014-v3-web-rust.md) · [RFC-010](../rfc/010-web-client.md)

---

## Goal

Browser-based Forja with shared logic in Rust (WASM), HLS-only playback, optional cloud sync.

Can start anytime after [Phase 1](./01-rust-engine.md) crates are stable. Best after [Phase 2](./02-rust-engine-complete.md) engine is complete.

---

## Exit criteria

- [ ] Engine crates compile to WASM (`wasm_bindgen`)
- [ ] Web app loads browse + plays HLS stream
- [ ] No libtorrent in web bundle
- [ ] IPTV parse + provider templates work via WASM

---

## Tasks

| ID | Task | Detail |
|----|------|--------|
| P5-01 | WASM build pipeline | `wasm_bindgen` for `forja-utils`, `forja-iptv-core`, `forja-stream-core` |
| P5-02 | Web app scaffold | `apps/forja_web/` or guarded web target |
| P5-03 | HLS-only playback | Hide torrent/magnet; video element or hls.js |
| P5-04 | Shared WASM module | IPTV parse + provider URL templates |
| P5-05 | Optional Supabase sync | RFC-006 backend on web |

---

## Scope limits (web)

| Capability | Web |
|------------|-----|
| Browse / details | yes |
| HLS/MP4 playback | yes |
| Torrent / libtorrent | **no** |
| IPTV live | HLS-only streams |
| Download / magnet | hidden |
| WebView extractors | limited — server-side or simplified paths |

---

## Relationship to other phases

```mermaid
flowchart LR
  P1["Phase1 Rust crates"]
  P2["Phase2 Engine complete"]
  P3["Phase3 Compose"]
  P4["Phase4 Delete Flutter"]
  P5["Phase5 Web WASM"]

  P1 --> P2 --> P3 --> P4
  P1 --> P5
  P2 --> P5
```

---

## Related

- [Migration index](./README.md)
- [RFC-014](../rfc/014-v3-web-rust.md)
- [RFC-009](../rfc/009-rust-ffi.md)
