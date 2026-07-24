# 102 — Android TV ExoPlayer video frames tiled / shifted

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android Media3 ExoPlayer · Flutter PlatformView · Anime / VOD

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I102-T01 | Inflate Media3 `PlayerView` with `surface_type=texture_view` (not default SurfaceView) | ✅ |
| 2 | I102-T02 | Document why TextureView is required for Flutter AndroidView compositing | ✅ |

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

**Root fix:** inflate `R.layout.forja_exo_player_view` with `app:surface_type="texture_view"` so the decoder targets a TextureView (a normal View) that Flutter can composite correctly. Same PlatformView hosts VOD + IPTV Exo on Android.

**Not a workaround:** TextureView is the supported Media3 surface for embedding inside non-SurfaceView parents / Flutter platform views.

## Related

- [RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md) — ExoPlayer Android built-in
- [031](031-[workaround]-android-tv-webview-gles-crash.md) — separate ATV WebView GLES track
- [Player](../features/playback/player.md)
