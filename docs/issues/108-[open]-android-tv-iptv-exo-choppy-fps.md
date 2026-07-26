# 108 — Android TV IPTV ExoPlayer choppy FPS on weak / Android 7 SoCs

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · Media3 ExoPlayer · TextureView · MediaKit  
**Reported:** 2026-07-25 (Toshiba Android 7 TV)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I108-T01 | Exo `open`: live LoadControl + LiveConfiguration + device max video size/bitrate (API ≤25 → 720p, ATV → 1080p) | ✅ |
| 2 | I108-T02 | IPTV ATV Exo open passes `live` from URL (`/live/` / M3U vs `/movie/` `/series/`) | ✅ |
| 3 | I108-T03 | Unit test `iptvExoUrlLooksLive` | ✅ |
| 4 | I108-T04 | Drop automatic live height/bitrate caps; shorter live target offset (~8s) — caps made picture soft / unwatchable | ✅ |
| 5 | I108-T05 | IPTV honors Settings / Player menu Exo ↔ MediaKit (ATV MediaKit uses `vo=mediacodec_embed`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I108-A01 | Toshiba Android 7 TV (or API 24 leanback): IPTV **live** channel plays without constant choppy FPS (Home/Search movies still smooth) | ⬜ |
| 2 | I108-A02 | Newer ATV: live IPTV still opens; adaptive HLS stays ≤1080p when variants exist | ⬜ |
| 3 | I108-A03 | Android TV IPTV **Player** menu switches Exo ↔ MediaKit and shows video (not black) on MediaKit | ⬜ |

---

## Summary

On **Android TV**, IPTV and Home/Search movies both use Media3 ExoPlayer + TextureView by default. Home VOD was smooth; **IPTV live** felt like constant low FPS on a Toshiba Android 7 set.

**Root cause (initial):** Live Xtream/M3U feeds are often fixed high-bitrate MPEG-TS (or high HLS variants) at the live edge. The shared Exo host had **no live LoadControl**, **no LiveConfiguration**, and **no max video size/bitrate** — while movie playback uses ABR + device caps in source selection. Weak API 24 TV SoCs + TextureView compositing fall behind first on live.

**First fix (T01–T03):** when Dart opens with `live: true` (IPTV live URLs), native Exo applies larger live buffers, a live offset, and track caps (720p / ~3.5 Mbps on API ≤25; 1080p / ~5 Mbps on other ATV).

**Follow-up (T04–T05):** device caps made live look soft / low-FPS and unwatchable. Caps are removed (LoadControl + ~8s live offset remain). IPTV now reads **Settings → Built-in engine** and the in-player **Player** menu can hot-swap Exo ↔ MediaKit; ATV MediaKit uses `vo=mediacodec_embed` + `hwdec=mediacodec` (same as VOD).

**Limit:** single-variant TS above what the SoC can decode still hitch — try **MediaKit** from the Player menu. TextureView compositing cost remains (required for Flutter — see issue 102).

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — TextureView compositing (required for Flutter)
- [092](092-[open]-windows-iptv-stream-freeze-after-20s.md) — Windows MediaKit IPTV freeze (separate)
- [107](fixed/107-[fixed]-android-7-tmdb-lets-encrypt-trust.md) — same Toshiba device, posters only
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../features/playback/player.md)
