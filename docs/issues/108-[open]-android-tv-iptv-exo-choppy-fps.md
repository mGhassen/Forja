# 108 — Android TV IPTV ExoPlayer choppy FPS on weak / Android 7 SoCs

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · Media3 ExoPlayer · TextureView  
**Reported:** 2026-07-25 (Toshiba Android 7 TV)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I108-T01 | Exo `open`: live LoadControl + LiveConfiguration + device max video size/bitrate (API ≤25 → 720p, ATV → 1080p) | ✅ |
| 2 | I108-T02 | IPTV ATV Exo open passes `live` from URL (`/live/` / M3U vs `/movie/` `/series/`) | ✅ |
| 3 | I108-T03 | Unit test `iptvExoUrlLooksLive` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I108-A01 | Toshiba Android 7 TV (or API 24 leanback): IPTV **live** channel plays without constant choppy FPS (Home/Search movies still smooth) | ⬜ |
| 2 | I108-A02 | Newer ATV: live IPTV still opens; adaptive HLS stays ≤1080p when variants exist | ⬜ |

---

## Summary

On **Android TV**, IPTV and Home/Search movies both use Media3 ExoPlayer + TextureView. Home VOD was smooth; **IPTV live** felt like constant low FPS on a Toshiba Android 7 set.

**Root cause:** Live Xtream/M3U feeds are often fixed high-bitrate MPEG-TS (or high HLS variants) at the live edge. The shared Exo host had **no live LoadControl**, **no LiveConfiguration**, and **no max video size/bitrate** — while movie playback uses ABR + device caps in source selection. Weak API 24 TV SoCs + TextureView compositing fall behind first on live.

**Root fix:** when Dart opens with `live: true` (IPTV live URLs), native Exo applies larger live buffers, a ~15s target live offset, and track caps (720p / ~3.5 Mbps on API ≤25; 1080p / ~5 Mbps on other ATV). Home/Search Exo opens stay `live: false` (unchanged).

**Limit:** single-variant TS above the cap cannot be downscaled in-player — caps help adaptive multi-bitrate feeds; buffers/offset help underrun hitching on fixed TS.

**Not a workaround:** same Exo engine; live-tuned LoadControl and constraints are the correct Media3 knobs.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — TextureView compositing (required for Flutter)
- [092](092-[open]-windows-iptv-stream-freeze-after-20s.md) — Windows MediaKit IPTV freeze (separate)
- [107](fixed/107-[fixed]-android-7-tmdb-lets-encrypt-trust.md) — same Toshiba device, posters only
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../features/playback/player.md)
