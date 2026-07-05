# RFC-010: Web client

**Version:** v3.0  
**Status:** Not started

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

## Acceptance (v3.0)

- [ ] `flutter build web` succeeds
- [ ] Play HLS trailer from details screen
- [ ] IPTV M3U import works via WASM parser
- [ ] Magnet/torrent tabs hidden or show "desktop only"
- [ ] Optional Supabase login (RFC-006)

## Related

RFC-009 (WASM), RFC-006 (sync backend)
