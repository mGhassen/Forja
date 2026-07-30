# 138 — Android TV IPTV: MediaKit silent / Exo audio stutter on 4K

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · ExoPlayer · MediaKit · 4K live

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I138-T01 | Exo live: disable edge speed-ramp (0.97–1.03) only when video is UHD (≥2160p / ≥3840w); HD/FHD keep catch-up | ✅ |
| 2 | I138-T02 | ATV MediaKit: force `ao=audiotrack` + unmute; on UHD switch `video-sync=audio` (HD keeps `display-resample`) | ✅ |
| 3 | I138-T03 | Feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I138-A01 | Android TV IPTV Exo: 4K live channel — picture + audio without speed-warble stutter | ⬜ |
| 2 | I138-A02 | Android TV IPTV Exo: HD/FHD live still uses live edge catch-up (no regression vs pre-fix) | ⬜ |
| 3 | I138-A03 | Android TV IPTV MediaKit: channel that was picture-only gets audible AAC; HD MediaKit still smooth | ⬜ |

---

## Summary

On **Android TV** IPTV, some **4K** live channels (e.g. 3840×2160 h264 @ 50fps) showed:

1. **MediaKit** — picture OK, no sound (demux still reported AAC / bitrate).
2. **ExoPlayer** — picture + sound, but **audio stuttered**.

**Root (Exo):** Live `LiveConfiguration` speed catch-up (`0.97–1.03`) warbles audio when the SoC is busy on UHD. HD/FHD need that catch-up to stay near the live edge.

**Root (MediaKit):** ATV uses `video-sync=display-resample` + `framedrop=vo` for smooth leanback video. On UHD that path can starve `ao` while video still paints. Exit path can also leave `ao=null` until a full recreate.

**Fix:** Exo wraps `LivePlaybackSpeedControl` and returns `1.0` only when decoded size is UHD (no mid-stream `replaceMediaItem`). MediaKit restores `ao=audiotrack` / unmute after open; UHD only flips to `video-sync=audio`.

## Related

- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — live LoadControl / display-resample
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — opposite: sound, black picture
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../features/playback/player.md)
