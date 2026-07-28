# 102 — Android TV ExoPlayer video frames tiled / shifted

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android Media3 ExoPlayer · Flutter PlatformView · Anime / VOD

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |
| **Current slice** | Phone TextureView; ATV SurfaceView + hybrid composition |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I102-T01 | Inflate Media3 `PlayerView` with `surface_type=texture_view` (not default SurfaceView) | ✅ |
| 2 | I102-T02 | Document why TextureView is required for Flutter AndroidView compositing | ✅ |
| 3 | I102-T03 | Android TV: SurfaceView + Flutter hybrid composition (`initExpensiveAndroidView`) — TextureView low-FPS on leanback; phone keeps TextureView | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I102-A01 | Android TV (emulator or device): Anime ExoPlayer episode shows one coherent frame — no tiled / shifted seams | ⬜ |
| 2 | I102-A02 | Android phone: ExoPlayer VOD still plays with correct aspect (regression) | ⬜ |

---

## Summary

Android TV Anime (and other ExoPlayer paths) showed a broken video surface: the same frame appeared **tiled / shifted** with hard seams while audio and chrome were fine (Megaplay HLS observed on leanback emulator).

**Root cause:** `ExoPlayerPlatformView` constructed `PlayerView(context)`, which defaults to **SurfaceView**. Flutter’s `AndroidView` composites via TLHC / VirtualDisplay; a nested SurfaceView is drawn at the wrong place / crop, which looks like a mirrored or tiled frame. Forja already knew ATV remounts VirtualDisplay surfaces (playback drop fix); this is the compositing sibling.

**First fix (T01–T02):** inflate `R.layout.forja_exo_player_view` with `app:surface_type="texture_view"` so the decoder targets a TextureView (a normal View) that Flutter can composite correctly under TLHC. Phone still uses this path.

**ATV follow-up (T03):** TextureView fixed tiling but felt soft / low-FPS on leanback (poor frame timing; UI layer often below full display resolution — Media3 prefers SurfaceView on TV). ATV now inflates SurfaceView and embeds with **hybrid composition** so SurfaceView is not mis-composited. Same PlatformView hosts VOD + IPTV Exo on Android.

**Not a workaround:** TextureView remains correct for phone TLHC; SurfaceView + hybrid composition is the supported path for ATV performance.

## Related

- [RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md) — ExoPlayer Android built-in
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — IPTV live choppy FPS (SurfaceView slice)
- [031](031-[workaround]-android-tv-webview-gles-crash.md) — separate ATV WebView GLES track
- [Player](../features/playback/player.md)
