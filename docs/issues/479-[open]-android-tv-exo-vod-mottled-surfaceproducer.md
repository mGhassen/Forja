# 479 — Android TV Exo VOD mottled picture (SurfaceProducer)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Media3 ExoPlayer · Asian Drama / Home films · TextureRegistry  
**Reported:** 2026-10-23 (physical Xiaomi Android 14 TV)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |
| **Current slice** | Device acceptance on Xiaomi A14 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On physical Xiaomi Android 14 TV, **ExoPlayer** Asian Drama / Home films show a mottled / speckled (moucheté) picture. **MediaKit** on the same titles is clean. Not KissKh-specific — shared VOD Exo path.

## Root cause (hypothesis until verified on device)

Exo paints through a PlatformView **TextureView** copy (`allowSurfaceView: false`, issue 133). MediaKit paints HW into Flutter via `mediacodec_embed` / SurfaceProducer. TextureView GPU copy / TLHC on that SoC produces mottling. SurfaceView HC stays parked (audio-only black on physical ATV).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I479-T01 | Kotlin: allocate Flutter `SurfaceProducer`, bind `ExoPlayer.setVideoSurface`, surface available/cleanup | ✅ |
| 2 | I479-T02 | Dart: `ExoPlayerBridge.create` → `Texture(textureId)`; drop PlatformView video plane for Exo mounts | ✅ |
| 3 | I479-T03 | Dart resize modes (fit/fill/zoom) via FittedBox + native `videoSize` events | ✅ |
| 4 | I479-T04 | Wire create on VOD Exo + IPTV Exo + Live Sports Exo boots | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I479-A01 | Xiaomi A14 ATV: Asian Drama + Home film on **Exo** — no mottled/speckle; MediaKit still works | ⬜ |
| 2 | I479-A02 | Phone Exo VOD still plays with correct aspect / resize modes | ⬜ |

## Links

- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — named TextureRegistry architectural fix
- [133](133-[open]-android-tv-exo-physical-audio-only.md) — why SurfaceView is parked
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — ATV SurfaceTexture producers
- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — tiled seams (different symptom)
