# 233 — Android TV Exo IPTV: periodic buffering (Xiaomi A11)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · ExoPlayer · continuity proxy

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I233-T01 | Exo Xtream/M3U live opens via `IptvLiveContinuityProxy` (same loopback as MediaKit) | ✅ |
| 2 | I233-T02 | ATV Exo live: deeper LoadControl + ~18s target offset; live speed catch-up locked to 1.0 | ✅ |
| 3 | I233-T03 | Feature doc + changelog — Exo play-through on CDN reconnect | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I233-A01 | Xiaomi A11 (or similar ATV): Xtream live on Exo plays ≥5 min without clockwork Buffering every few seconds | ⬜ |
| 2 | I233-A02 | Same channel on MediaKit still play-through on CDN reopen (no regression) | ⬜ |

---

## Summary

**Symptom:** On Android TV (reported Xiaomi / Android 11), IPTV live on **ExoPlayer** entered **Buffering** every few seconds while MediaKit on the same channel stayed smoother.

**Root:** MediaKit Xtream/M3U live uses `IptvLiveContinuityProxy` (loopback + upstream reopen). Exo opened the CDN URL directly, so every portal socket close became a hard underrun. ATV Exo also sat ~8s behind the live edge with 0.97–1.03 catch-up, which drained the cushion and re-triggered `STATE_BUFFERING` in a cycle.

**Fix:** Route Exo through the same continuity proxy for Xtream/M3U live. On Android TV, deepen live LoadControl (~25–70s), target offset ~18s, and lock live playback speed to 1.0 (phone HD/FHD keep catch-up; UHD already locked — issue 138).

**Not in 1.4.238:** that tag only shipped recovery Auto / nav restore — no Exo buffer work.

## Related

- [108](../108-[open]-android-tv-iptv-exo-choppy-fps.md) — Exo choppy FPS (TextureView / frame pacing)
- [199](../199-[open]-android-tv-iptv-mediakit-silent-underrun-engine-swap.md) — MediaKit CDN reconnect play-through
- [138](../138-[open]-android-tv-iptv-4k-audio.md) — UHD Exo speed lock
- [IPTV Xtream](../../features/live/iptv-xtream.md)
