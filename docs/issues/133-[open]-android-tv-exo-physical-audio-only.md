# 133 — Android TV physical ExoPlayer: sound but no video

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Media3 ExoPlayer · SurfaceView · physical leanback  
**Reported:** 2026-07-29 (physical ATV, Exo cold-open)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 2** acceptance |
| **Current slice** | Home/VOD forced TextureView; IPTV SurfaceView + hardened watchdog |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I133-T01 | Native Exo emit `renderedFirstFrame` (surface health signal) | ✅ |
| 2 | I133-T02 | Process-lifetime ATV TextureView prefer flag + `ExoPlayerView` remount | ✅ |
| 3 | I133-T03 | VOD Exo: watchdog / surface-error → TextureView remount + reopen | ✅ |
| 4 | I133-T04 | IPTV Exo: same surface fallback path | ✅ |
| 5 | I133-T05 | Home/VOD Exo: never request SurfaceView (`allowSurfaceView: false`) — TextureView only | ✅ |
| 6 | I133-T06 | IPTV SurfaceView watchdog: arm on READY (no play gate) + progress-without-frame trigger | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I133-A01 | Physical Android TV: Home/Search Exo VOD cold-open shows video + audio (TextureView) | ⬜ |
| 2 | I133-A02 | Physical Android TV: Exo IPTV live shows video after fallback when SurfaceView is dead; phone / emulator path unchanged | ⬜ |

---

## Summary

On **physical Android TV**, Exo used **SurfaceView + hybrid composition** for frame timing (issues 102 / 108). Emulators already force **TextureView** because SurfaceView + MediaCodec often fails `setOutputSurface` → **audio continues, picture stays black**.

Some **real** sticks/boxes hit the same silent surface bind failure. A watchdog (T01–T04) remounts TextureView when READY/playing never gets `renderedFirstFrame`. That is **not enough** when the surface is composition-dead but still emits first-frame — Home/VOD stayed audio-only.

**Root fix (VOD):** Home/Search/movies Exo **always** uses TextureView (`allowSurfaceView: false`). Do not wait for a watchdog.

**IPTV:** May still opt into SurfaceView for live FPS; watchdog stays enabled and now arms on READY alone and triggers if position advances without a first frame.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling / hybrid composition
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — ATV SurfaceView for live FPS; emulator TextureView
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — MediaKit Impeller audio-only (separate)
- [Player](../features/playback/player.md)
