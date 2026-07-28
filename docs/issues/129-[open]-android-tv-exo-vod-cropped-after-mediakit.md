# 129 — Android TV ExoPlayer VOD cropped / zoomed after MediaKit → Exo

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · ExoPlayer · Anime / Movies / Asian Drama  
**Reported:** 2026-07-28 (Player menu MediaKit → ExoPlayer)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I129-T01 | ATV SurfaceView `PlayerView`: enable Media3 `setEnableComposeSurfaceSyncWorkaround(true)` (API 34+ crop) | ✅ |
| 2 | I129-T02 | Explicit `resize_mode=fit` in Exo layouts + re-assert FIT on PlatformView attach | ✅ |
| 3 | I129-T03 | VOD `ExoPlayerScreen`: wrap `ExoPlayerView` in `Positioned.fill` (parity with IPTV / MediaKit) | ✅ |
| 4 | I129-T04 | Always re-apply Dart resize mode after Exo `open` / source switch (not only when ≠ fit) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I129-A01 | Android TV: anime/movie/drama — Player menu MediaKit → ExoPlayer shows full letterboxed frame (not zoomed crop) | ⬜ |
| 2 | I129-A02 | Android TV: cold-open ExoPlayer (no MediaKit first) still fits correctly; IPTV Exo SurfaceView unchanged | ⬜ |

---

## Summary

On Android TV, switching the built-in engine from **MediaKit** to **ExoPlayer** in anime / movies / Asian Drama left the video **zoomed** — only part of the frame visible (looked cropped).

**Root cause (two layers):**

1. **Media3 SurfaceView sync (primary)** — ATV Exo embeds `PlayerView` with `surface_type=surface_view` via Flutter hybrid composition. On API 34+, SurfaceView inside an AndroidView-style host can paint at the wrong scale until Media3’s opt-in `setEnableComposeSurfaceSyncWorkaround(true)` runs ([androidx/media#1237](https://github.com/androidx/media/issues/1237)). Forja ships Media3 **1.5.1** where the workaround is opt-in.
2. **Layout remount** — VOD `ExoPlayerScreen` did not wrap the PlatformView in `Positioned.fill` (IPTV / MediaKit already did). After an engine swap, a loose Stack child can get a bad surface size that reads as a crop.

**Not a workaround:** enabling the Media3 API is the supported fix for SurfaceView-in-AndroidView; FIT + `Positioned.fill` restore correct letterboxing after remount.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling / hybrid composition
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — ATV SurfaceView for live FPS
- [RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md)
- [Player](../features/playback/player.md)
