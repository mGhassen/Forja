# 129 — Android TV ExoPlayer VOD cropped / zoomed after MediaKit → Exo

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · ExoPlayer · Anime / Movies / Asian Drama  
**Reported:** 2026-07-28 (Player menu MediaKit → ExoPlayer)

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I129-T01 | ATV SurfaceView `PlayerView`: enable Media3 `setEnableComposeSurfaceSyncWorkaround(true)` (API 34+ crop) | ✅ |
| 2 | I129-T02 | Explicit `resize_mode=fit` in Exo layouts + re-assert FIT on PlatformView attach | ✅ |
| 3 | I129-T03 | VOD `ExoPlayerScreen`: wrap `ExoPlayerView` in `Positioned.fill` (parity with IPTV / MediaKit) | ✅ |
| 4 | I129-T04 | Always re-apply Dart resize mode after Exo `open` / source switch (not only when ≠ fit) | ✅ |
| 5 | I129-T05 | VOD Player menu engine switch: unmount → `endOfFrame` → await MediaKit dispose → then mount Exo (IPTV parity) | ✅ |
| 6 | I129-T06 | Mobile/TV MediaKit: `trackPlayer` + `trackVideoDispose` so hot-swap can await teardown | ✅ |
| 7 | I129-T07 | `ExoPlayerScreen._boot` awaits `prepareForVideoPlayer` before open | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I129-A01 | Android TV: anime/movie/drama — Player menu MediaKit → ExoPlayer shows full letterboxed frame (not zoomed crop) | ⬜ |
| 2 | I129-A02 | Android TV: cold-open ExoPlayer (no MediaKit first) still fits correctly; IPTV Exo SurfaceView unchanged | ⬜ |

---

## Summary

On Android TV, switching the built-in engine from **MediaKit** to **ExoPlayer** in anime / movies / Asian Drama left the video **zoomed** — only part of the frame visible (bottom half / huge burned-in subs), chrome correct.

**Root cause (verified after T01–T04 alone failed):**

VOD `PlayerScreen._switchPlayer` did an **instant** `setState` engine swap. MediaKit (`vo=mediacodec_embed`) dispose ran **fire-and-forget** while Exo’s TextureView/PlatformView mounted in the same turn. Exo attached over a half-dead MediaCodec surface → wrong scale (zoomed crop). IPTV already unmounted → `endOfFrame` → awaited dispose → boot; VOD did not. Mobile MediaKit also never called `trackVideoDispose`, so nothing could wait.

**Earlier T01–T04** (Media3 surface-sync, FIT, `Positioned.fill`) remain correct hygiene but were **not** sufficient alone for this switch path.

**Root fix (T05–T07):** IPTV-style switch gate + tracked MediaKit teardown + Exo boot waits on pending dispose.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling / hybrid composition
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — ATV SurfaceView for live FPS
- [128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) — MediaKit surface teardown races
- [RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md)
- [Player](../features/playback/player.md)
