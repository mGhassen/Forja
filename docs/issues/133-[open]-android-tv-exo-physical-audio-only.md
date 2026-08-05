# 133 — Android TV physical ExoPlayer: sound but no video

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Media3 ExoPlayer · SurfaceView · physical leanback  
**Reported:** 2026-07-29 (physical ATV, Exo cold-open)

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 3** acceptance |
| **Current slice** | Home/VOD forced TextureView; IPTV SurfaceView on cold open only, TextureView after a MediaKit hot swap |

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
| 7 | I133-T07 | IPTV Player menu MediaKit → Exo: force TextureView for the rest of the route (`allowSurfaceView: false`) and skip the surface watchdog | ✅ |
| 8 | I133-T08 | IPTV switch to Exo awaits the tracked MediaKit dispose (capped 1.2s) before Exo mounts — parity with the VOD switch | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I133-A01 | Physical Android TV: Home/Search Exo VOD cold-open shows video + audio (TextureView) | ⬜ |
| 2 | I133-A02 | Physical Android TV: Exo IPTV live shows video after fallback when SurfaceView is dead; phone / emulator path unchanged | ⬜ |
| 3 | I133-A03 | Physical Android TV: IPTV Player menu MediaKit → ExoPlayer shows video + audio and the player chrome stays reachable (Player menu can switch back) | ⬜ |

---

## Summary

On **physical Android TV**, Exo used **SurfaceView + hybrid composition** for frame timing (issues 102 / 108). Emulators already force **TextureView** because SurfaceView + MediaCodec often fails `setOutputSurface` → **audio continues, picture stays black**.

Some **real** sticks/boxes hit the same silent surface bind failure. A watchdog (T01–T04) remounts TextureView when READY/playing never gets `renderedFirstFrame`. That is **not enough** when the surface is composition-dead but still emits first-frame — Home/VOD stayed audio-only.

**Root fix (VOD):** Home/Search/movies Exo **always** uses TextureView (`allowSurfaceView: false`). Do not wait for a watchdog.

**IPTV:** May still opt into SurfaceView for live FPS; watchdog stays enabled and now arms on READY alone and triggers if position advances without a first frame.

## MediaKit → Exo hot swap (T07–T08)

Reported again on a **released** build: physical ATV, IPTV, Player menu **MediaKit → ExoPlayer** → sound plays, picture stays black, and the player chrome is unreachable (the native SurfaceView covers it, so the Player menu cannot switch back).

**Root cause (code-verified, device smoke pending):** the swap mounted a SurfaceView + hybrid-composition Exo view over the MediaKit surface that was still being released.

- `IptvPtPlayerScreen._switchBuiltInEngine` awaited `MpvExclusiveSession.prepareForVideoPlayer()` only when switching **to** MediaKit — the Exo direction had just a 250 ms cool-down, while `_releaseEngineForHotSwap` leaves MediaKit `stop`+`dispose` tracked and unawaited. VOD (`player_screen.dart`, issue 129 T05 / 128 T07) already awaits it with a 1.2 s cap. ATV MediaCodec is shared even though the mpv handle is not, so Exo bound over a half-dead `mediacodec_embed` surface.
- The surface watchdog cannot rescue this: `onRenderedFirstFrame` still fires, so `ExoAtvSurfaceFallback` stands down and never remounts TextureView (same blind spot as the VOD case above).

**Fix:** IPTV keeps SurfaceView only on a **cold** Exo open. Once MediaKit has run in that route (`_exoAfterMediaKit`), Exo mounts as TextureView — composited by Flutter, so it can neither bind dead nor cover the chrome — and the surface watchdog is disabled for that session (a slow TextureView first frame would otherwise force a pointless reopen). The Exo direction of the switch now awaits the tracked MediaKit dispose, capped at 1.2 s so it cannot cross the ATV input-ANR window (issue 128).

**Not fixed by this:** a device where **cold-open** IPTV Exo is also audio-only black. That is still the SurfaceView path guarded only by the watchdog (A02). If it reproduces, IPTV must drop SurfaceView entirely like VOD (T05) and issue 108 loses its FPS slice.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling / hybrid composition
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — ATV SurfaceView for live FPS; emulator TextureView
- [129](129-[open]-android-tv-exo-vod-cropped-after-mediakit.md) — VOD MediaKit → Exo over a half-dead surface (same swap gate)
- [128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) — why the MediaKit dispose wait is capped
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — MediaKit Impeller audio-only (separate)
- [Player](../features/playback/player.md)
