# 182 — Android TV paused sleep shows green video surface

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** player · Android TV · ExoPlayer · MediaKit · IPTV

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I182-T01 | VOD Exo: on ATV resume while still paused, black-cover dead TextureView until play | ✅ |
| 2 | I182-T02 | VOD MediaKit: same cover over `mediacodec_embed` until play | ✅ |
| 3 | I182-T03 | IPTV (Exo + MediaKit): same cover on ATV resume-while-paused | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I182-A01 | Physical ATV: pause VOD → TV veille → return → player is black (not green); play restores picture | ⬜ |
| 2 | I182-A02 | Physical ATV IPTV: same pause → veille → return → black then play OK | ⬜ |

---

## Summary

Pause on Android TV, let the set sleep (veille / HDMI off), return while still paused: video area is **green**. Play restores the picture.

**Cause:** sleep destroys the MediaCodec / TextureView / `mediacodec_embed` surface. Empty YUV (U=V=0) paints green. Paused decode never pushes a replacement frame. Lifecycle only auto-plays when **we** paused for background (`_pausedByLifecycle`) — user pause is a no-op on resume.

**Fix (cheap):** ATV-only black `ColoredBox` over the video on `resumed` when still paused; clear when playback starts. No seek, no surface rebind.
