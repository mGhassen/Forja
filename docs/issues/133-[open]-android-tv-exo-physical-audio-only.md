# 133 — Android TV physical ExoPlayer: sound but no video

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Media3 ExoPlayer · SurfaceView · physical leanback  
**Reported:** 2026-07-29 (physical ATV, Exo cold-open)

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** fix · **0 / 3** acceptance |
| **Current slice** | Home/VOD **and** IPTV both TextureView; ATV IPTV keeps ExoPlayer (T09 MediaKit default reverted by T10) |

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
| 7 | I133-T07 | IPTV Exo: always TextureView (`allowSurfaceView: false`) + surface watchdog off — SurfaceView was audio-only black even on cold open, same as VOD (T05) | ✅ |
| 8 | I133-T08 | IPTV switch to Exo awaits the tracked MediaKit dispose (capped 1.2s) before Exo mounts — parity with the VOD switch | ✅ |
| 9 | I133-T09 | ATV unset IPTV engine → MediaKit (do not inherit VOD Exo); TextureView Exo live is soft / low-FPS on leanback — **reverted by T10, never released** | ✅ |
| 10 | I133-T10 | Revert T09: unset ATV IPTV inherits the VOD engine again. Defaulting away from Exo abandoned the engine instead of fixing it; the TextureView judder is addressed on the Exo side in issue 108 (T11–T13) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I133-A01 | Physical Android TV: Home/Search Exo VOD cold-open shows video + audio (TextureView) | ⬜ |
| 2 | I133-A02 | Physical Android TV: Exo IPTV live **cold open** shows video + audio (TextureView); phone / emulator path unchanged | ⬜ |
| 3 | I133-A03 | Physical Android TV: IPTV Player menu MediaKit → ExoPlayer shows video + audio and the player chrome stays reachable (Player menu can switch back) | ⬜ |

---

## Summary

On **physical Android TV**, Exo used **SurfaceView + hybrid composition** for frame timing (issues 102 / 108). Emulators already force **TextureView** because SurfaceView + MediaCodec often fails `setOutputSurface` → **audio continues, picture stays black**.

Some **real** sticks/boxes hit the same silent surface bind failure. A watchdog (T01–T04) remounts TextureView when READY/playing never gets `renderedFirstFrame`. That is **not enough** when the surface is composition-dead but still emits first-frame — Home/VOD stayed audio-only.

**Root fix (VOD):** Home/Search/movies Exo **always** uses TextureView (`allowSurfaceView: false`). Do not wait for a watchdog.

**IPTV (initial):** kept SurfaceView for live FPS with the watchdog armed on READY alone (T06). **Superseded by T07** — see below.

## IPTV also drops SurfaceView (T07–T08)

Reported again on a **released** build: physical ATV, IPTV, Player menu **MediaKit → ExoPlayer** → sound plays, picture stays black, and the player chrome is unreachable (the native SurfaceView covers it, so the Player menu cannot switch back). The reporter confirmed the **same on IPTV Exo cold open** (engine set to ExoPlayer in Settings, channel opened fresh with no MediaKit in the session) — so this is the SurfaceView path itself, not only the swap.

**Root cause (code-verified, device smoke pending):**

- **SurfaceView is dead on this device.** SurfaceView + hybrid composition never paints (audio-only black) and its Surface covers the Flutter overlay. The watchdog cannot rescue it: `onRenderedFirstFrame` still fires on the composition-dead surface, so `ExoAtvSurfaceFallback` stands down and never remounts TextureView — the same blind spot that forced VOD to TextureView in T05.
- **The MediaKit → Exo swap made it worse.** `IptvPtPlayerScreen._switchBuiltInEngine` awaited `MpvExclusiveSession.prepareForVideoPlayer()` only when switching **to** MediaKit — the Exo direction had just a 250 ms cool-down, while `_releaseEngineForHotSwap` leaves MediaKit `stop`+`dispose` tracked and unawaited. VOD (`player_screen.dart`, issue 129 T05 / 128 T07) already awaits it with a 1.2 s cap. ATV MediaCodec is shared even though the mpv handle is not, so Exo bound over a half-dead `mediacodec_embed` surface.

**Fix (T07):** IPTV Exo now **always** uses TextureView on ATV (`allowSurfaceView: false`) — composited by Flutter, so it can neither bind dead nor cover the chrome — and the surface watchdog is disabled (`ExoAtvSurfaceFallback(enabled: false)`; a slow TextureView first frame would otherwise trigger a pointless reopen). This matches VOD (T05). The `SurfaceView` machinery (`ExoPlayerView.allowSurfaceView`, `_AtvExoSurfaceView`, `forja_exo_player_view_surface`, the watchdog) is kept wired for a possible **per-device opt-in** later, but nothing requests it now.

**Fix (T08):** the Exo direction of the Player-menu switch now awaits the tracked MediaKit dispose, capped at 1.2 s so it cannot cross the ATV input-ANR window (issue 128).

**Trade-off:** issue 108 chose SurfaceView for smoother live FPS on weak / Android 7 SoCs (I108-T06). TextureView may feel less fluid there — but a black picture is worse. Issue 108's SurfaceView FPS slice stays parked until a per-device SurfaceView opt-in exists.

**T09 reverted (T10).** T09 made unset ATV IPTV default to **MediaKit** so the TextureView judder would not be the first thing a user meets. That was the wrong call: it routed users away from ExoPlayer rather than making Exo fluid, and it never shipped in a tag. Unset ATV IPTV inherits the VOD engine again (Exo on Android). The judder itself is now attacked on the Exo side — live display frame-rate matching, async MediaCodec queueing, and frame-health logging — in [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) T11–T13.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling / hybrid composition
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — ATV SurfaceView for live FPS; emulator TextureView
- [129](129-[open]-android-tv-exo-vod-cropped-after-mediakit.md) — VOD MediaKit → Exo over a half-dead surface (same swap gate)
- [128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) — why the MediaKit dispose wait is capped
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — MediaKit Impeller audio-only (separate)
- [Player](../features/playback/player.md)
