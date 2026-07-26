# RFC-029: Dual built-in playback engines (media_kit + ExoPlayer)

**Status:** open  
**Depends on:** [RFC-026](026-[draft]-media-details-player-ux.md) (player chrome), [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) C6  
**Area:** `apps/forja/android/`, `apps/forja/lib/shared/player/`, `packages/rust/lib/src/settings_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **1 / 8** acceptance (phase 1) |
| **Current slice** | Android dual-engine MVP — settings toggle + ExoPlayer VOD path; external SRT/VTT sideload shipped |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R29-C01 | `BuiltInPlayerEngine` setting + platform defaults (Android → ExoPlayer) | ✅ |
| 2 | R29-C02 | Kotlin Media3 PlatformView + method/event channels | ✅ |
| 3 | R29-C03 | `ExoPlayerScreen` — VOD path behind `PlayerScreen` router | ✅ |
| 4 | R29-C04 | Settings UI + feature docs | ✅ |

---

## Acceptance (phase 1 — Android VOD)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R29-A01 | Settings → Built-in engine visible on Android; default ExoPlayer; desktop/iOS hidden | ⬜ |
| 2 | R29-A02 | Built-in + ExoPlayer: HLS/mp4 plays with custom headers | ⬜ |
| 3 | R29-A03 | `sources` list failover on open/play error | ⬜ |
| 4 | R29-A04 | Resume `startPosition` seeks after ready | ⬜ |
| 5 | R29-A05 | External SRT/VTT via ExoPlayer subtitle track | ✅ |
| 6 | R29-A06 | Built-in + MediaKit: mobile player still works (Android fallback) | ⬜ |
| 7 | R29-A07 | ATV D-pad play/pause/seek/back on ExoPlayer path | ⬜ |
| 8 | R29-A08 | `onSaveProgress` / scrobble hooks fire on ExoPlayer path | ⬜ |

---

## Deferred (phase 2+)

| Feature | Engine |
|---------|--------|
| ASS/SSA libass | media_kit only — [issue 032](../issues/032-[draft]-exoplayer-parity-gaps.md) |
| Local torrent `127.0.0.1` | media_kit until verified — issue 024 |
| Seek preview screenshots | media_kit — RFC-026 |
| HLS manual quality picker | Exo auto variant only |
| PiP, separate `audioUrl` | media_kit |
| IPTV live edge | media_kit — RFC-027 |

When ExoPlayer cannot handle a stream, show toast: *Switch to MediaKit in Settings → Built-in engine*.

---

## Summary

Android ships **two built-in decoders**: **Media3 ExoPlayer** (default) and **media_kit** (libmpv). User selects in **Settings → Playback → Built-in engine**. External player (VLC/MX) remains orthogonal.

Desktop and iOS always use media_kit.

## Related

- [issue 032](../issues/032-[draft]-exoplayer-parity-gaps.md) — parity gaps
- [playback-settings.md](../features/settings/playback-settings.md)
