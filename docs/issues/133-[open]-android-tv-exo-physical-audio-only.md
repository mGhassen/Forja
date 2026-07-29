# 133 — Android TV physical ExoPlayer: sound but no video

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Media3 ExoPlayer · SurfaceView · physical leanback  
**Reported:** 2026-07-29 (physical ATV, Exo cold-open)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I133-T01 | Native Exo emit `renderedFirstFrame` (surface health signal) | ✅ |
| 2 | I133-T02 | Process-lifetime ATV TextureView prefer flag + `ExoPlayerView` remount | ✅ |
| 3 | I133-T03 | VOD Exo: watchdog / surface-error → TextureView remount + reopen | ✅ |
| 4 | I133-T04 | IPTV Exo: same surface fallback path | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I133-A01 | Physical Android TV: Exo VOD cold-open shows video + audio (SurfaceView OK, or auto TextureView fallback) | ⬜ |
| 2 | I133-A02 | Physical Android TV: Exo IPTV live shows video after fallback when SurfaceView is dead; phone / emulator path unchanged | ⬜ |

---

## Summary

On **physical Android TV**, Exo uses **SurfaceView + hybrid composition** for frame timing (issues 102 / 108). Emulators already force **TextureView** because SurfaceView + MediaCodec often fails `setOutputSurface` → **audio continues, picture stays black**.

Some **real** sticks/boxes hit the same silent surface bind failure. Physical ATV had no fallback — SurfaceView stayed selected forever.

**Root fix:** Keep SurfaceView as the ATV default. If playback reaches READY / playing with a video track but **no `renderedFirstFrame`** within a short watchdog (or a surface-attach decoder error), flip a process-lifetime **prefer TextureView** flag, remount the PlatformView, and reopen at the current position. Same path for VOD and IPTV Exo.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling / hybrid composition
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — ATV SurfaceView for live FPS; emulator TextureView
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — MediaKit Impeller audio-only (separate)
- [Player](../features/playback/player.md)
