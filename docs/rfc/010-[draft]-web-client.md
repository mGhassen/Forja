# RFC-010: Web client

**Version:** v3.0  
**Status:** draft  
**Target version:** v3  
**Depends on:** RFC-009 (Rust/WASM)  
**Area:** `apps/forja` web build or `apps/forja_web/`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 5** acceptance (v3.0 slice) |
| **Current slice** | v3.0 — browser client + HLS playback |
| **Backlog** | v3 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v3.0)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R10-A01 | `flutter build web` succeeds | ⬜ |
| 2 | R10-A02 | Play HLS trailer from details screen | ⬜ |
| 3 | R10-A03 | IPTV M3U import works via WASM parser | ⬜ |
| 4 | R10-A04 | Magnet/torrent tabs hidden or show "desktop only" | ⬜ |
| 5 | R10-A05 | Optional Supabase login (RFC-006) | ⬜ |

---


## Summary

Browser-based Forja: browse, details, HLS playback. Shares Rust WASM core (RFC-009) where possible.

## Target

Option A: `flutter build web` from `apps/forja` with `kIsWeb` guards.  
Option B: separate `apps/forja_web/` slim shell.

Recommend Option A initially — reuse feature folders + shell.

## Capability matrix

| Feature | Web |
|---------|-----|
| Home, Discover, Search, Details | yes |
| HLS / MP4 playback | yes (video_tag / hls.js) |
| Stremio browse | yes (HTTP addons) |
| Torrent / magnet / libtorrent | **no** — hide nav tabs |
| IPTV live (HLS) | yes |
| IPTV (non-HLS) | no or proxy-only |
| Download / media downloader | hide |
| Jellyfin | yes (HTTP) |
| Settings sync | RFC-006 |
| PiP | browser PiP API |
| Cast | Chromecast via Cast SDK web |

## Architecture

```
Browser
  └── Flutter web (apps/forja)
        ├── features/* (kIsWeb guards)
        ├── shared/player (HLS-only backend)
        └── WASM (RFC-009) for IPTV parse + providers
```

## Bundle constraints

- Exclude `libtorrent_flutter`, native media_kit libs
- Tree-shake unused features (magnet, downloader) via conditional imports or flavor
- Target initial bundle < 15 MB gzipped (stretch)


## Related

RFC-009 (WASM), RFC-006 (sync backend)
