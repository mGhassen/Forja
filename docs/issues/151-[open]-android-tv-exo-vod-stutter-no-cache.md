# 151 — Android TV movie player (Exo VOD): judder + no media cache

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** Android TV · Media3 ExoPlayer · VOD playback  
**Reported:** 2026-08-05 (physical ATV, Home/Search movie, Exo engine)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 6** acceptance |
| **Current slice** | Frame-rate matching + VOD buffer/cache landed; device smoke pending |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I151-T01 | VOD `DefaultLoadControl`: deeper max buffer + RAM back buffer instead of media3 stock | ✅ |
| 2 | I151-T02 | `SimpleCache` + `CacheDataSource` disk cache for remote VOD (skip live, skip loopback URLs) | ✅ |
| 3 | I151-T03 | Window-level display frame-rate matching on ATV so 24 fps stops juddering on a 60 Hz output | ✅ |
| 4 | I151-T04 | `SeekParameters.PREVIOUS_SYNC` on TV VOD — keyframe seeks instead of exact | ✅ |
| 5 | I151-T05 | VOD `WAKE_MODE_NETWORK` (parity with live; TVs throttle decode when idle) | ✅ |
| 6 | I151-T06 | Dart: stop the 500 ms progress tick rebuilding the whole player tree while controls are hidden | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I151-A01 | Physical ATV: 24 fps movie pans smoothly — no repeating 3:2 cadence | ⬜ |
| 2 | I151-A02 | Backward seek inside already-watched footage resumes without a full rebuffer | ⬜ |
| 3 | I151-A03 | D-pad ±10 s on a movie responds without a multi-second stall | ⬜ |
| 4 | I151-A04 | Disk cache stays bounded and never fills TV storage | ⬜ |
| 5 | I151-A05 | Phone Exo VOD unchanged (no display mode switch, no keyframe-only seeks) | ⬜ |
| 6 | I151-A06 | IPTV live path unchanged — no regression against issues 108 / 133 / 138 | ⬜ |

---

## Summary

On physical Android TV the movie player stutters and does not feel fluid. The
user read it as a buffering problem. It is two independent defects that share
that symptom.

## Cause 1 — the render path cannot do frame-rate matching

ATV VOD is hard-forced to **TextureView**:

```dart
static String creationSurfaceType({bool allowSurfaceView = false}) {
  if (!allowSurfaceView) return 'texture';
```

`ExoPlayerScreen` builds `ExoPlayerView(viewId: _viewId)` with no
`allowSurfaceView`, so it always lands on `AndroidView` + `surface_type="texture_view"`.
That was deliberate — [issue 133](133-[open]-android-tv-exo-physical-audio-only.md)
T05 found SurfaceView goes audio-only black on real boxes.

The cost was not recorded at the time. With the decoder output going to a
`SurfaceTexture` composited by Flutter, Media3's `VideoFrameReleaseHelper` has no
window-layer surface to hint, so `Surface.setFrameRate` never reaches the display
and Android TV's *match content frame rate* never fires. 23.976 / 24 fps film on
a fixed 60 Hz output is then a permanent 3:2 pulldown. Live TV at 50/60 fps hides
it; movies do not — which is exactly why this was reported against movies and not
against IPTV.

**Fix (T03):** request the mode switch ourselves at the window level.
`ForjaDisplayFrameRate` picks a `Display.Mode` at the current resolution whose
refresh rate is an integer multiple of the content frame rate and sets
`preferredDisplayModeId`. Skipped when the current refresh already divides
cleanly, so 30 and 60 fps content never triggers an HDMI re-sync.

Content frame rate comes from `Format.frameRate`. Containers that omit it
(common for HLS) get no switch — honest limitation, not a silent fallback.

## Cause 2 — VOD never got the buffer work live got

```kotlin
val loadControl = if (options.live) {
    DefaultLoadControl.Builder().setBufferDurationsMs(…)…
} else {
    DefaultLoadControl.Builder().build()
}
```

VOD took media3 1.5.1 stock. Verified against the 1.5.1 tag:
`DEFAULT_BACK_BUFFER_DURATION_MS = 0`, `DEFAULT_TARGET_BUFFER_BYTES = LENGTH_UNSET`,
`DEFAULT_MAX_BUFFER_MS = 50_000`.

Grepping the whole Kotlin source for `SimpleCache|CacheDataSource|setBackBuffer|SeekParameters`
returned nothing. So there was **zero** back buffer and **zero** disk cache: every
backward seek discarded what had just played and re-fetched it from the CDN, and
`SeekParameters.DEFAULT` made every seek exact, forcing a decode from the previous
keyframe.

**Fix (T01/T02/T04):** deeper VOD load control with a 15 s RAM back buffer, a
bounded on-disk `SimpleCache` (LRU) in front of remote HTTP VOD only, and
keyframe seeks on TV.

Loopback URLs are excluded from the disk cache — librqbit torrent streams and the
Rust `/hls-proxy` are already local, so caching them would double the writes.

## Cause 3 (minor) — the UI rebuilt itself twice a second over the platform view

`startProgressLoop` posts every 500 ms and the Dart handler called `setState`
unconditionally. The controls overlay is always built (it is hidden with
`AnimatedOpacity`, not removed), so a movie watched with controls hidden rebuilt
and re-laid-out the entire controls tree 2×/s on top of the platform view.

**Fix (T06):** only rebuild when the controls are actually visible or when the
next-episode gate flips. Buffering already used a `ValueNotifier`; position did not.

## Not fixed here

SurfaceView remains off for VOD. Re-enabling it behind a per-device opt-in is the
real render fix and would make T03 unnecessary, but it is blocked on issue 133 —
the composition-dead surface still emits `renderedFirstFrame`, so no watchdog can
detect it. T03 is a genuine improvement to the TextureView path, not a substitute
for that work.

## Update — T03 now covers live too

T03 shipped with `applyContentFrameRate()` returning early on `lastOptions.live`,
reasoning that a live channel would pay an HDMI re-sync on every adaptive ladder
flip. That guard was too blunt: a 50 or 25 fps IPTV channel on a fixed 60 Hz panel
judders exactly like a 24 fps film does, which is the Toshiba report in issue 108.
The `frameRateApplied` one-shot already limits this to a single switch per open, so
a ladder flip cannot re-trigger a mode change mid-channel. The live exclusion is
removed; the work is tracked as I108-T11.

A06 below ("IPTV live path unchanged") was written under the VOD-only assumption —
live now intentionally gets the same mode switch.

## Related

- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — live side of the same render path (T11–T13)
- [133](133-[open]-android-tv-exo-physical-audio-only.md) — why VOD is on TextureView at all
- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling under hybrid composition
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — the live-side FPS slice parked by 133 T07
- [150](150-[open]-atv-iptv-4k-mediakit-stutter.md) — the MediaKit/IPTV sibling of this symptom
- [120](120-[open]-android-tv-player-memory-purge.md) — memory headroom the disk cache must respect
- [Player](../features/playback/player.md)
