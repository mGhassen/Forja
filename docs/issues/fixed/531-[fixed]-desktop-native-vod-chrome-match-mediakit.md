# 531 — Desktop native VOD chrome matches MediaKit

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Desktop · AVPlayer · libVLC · catalog VOD chrome  
**Reported:** 2026-11-03 (catalog AVPlayer/VLC had thin chrome vs MediaKit overlay)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I531-T01 | Pass MediaKit-parity props into `DesktopNativePlayerScreen` from `PlayerScreen` | ✅ |
| 2 | I531-T02 | Full desktop chrome overlay (top/center/bottom/right/floating) matching MediaKit widgets | ✅ |
| 3 | I531-T03 | Wire working handlers: fullscreen, cast, in-app mini, episodes, IntroDB skip, settings, sources/stream remount | ✅ |
| 4 | I531-T04 | Keep Audio/Subs/Quality/PiP buttons visible; toast stubs (no hide) | ✅ |
| 5 | I531-T05 | Changelog + RFC-107 acceptance append + follow-up 532 for native track/PiP APIs | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I531-A01 | Catalog VOD on AVPlayer/VLC shows MediaKit-parity chrome; Sources/episodes/cast/mini/settings work; Audio/Subs/Quality/PiP toast | ⬜ |

---

## Symptom

Catalog desktop AVPlayer / VLC used a stripped chrome (title, seek, transport, Player menu only). MediaKit had Sources, episodes, cast, in-app mini, PiP, Audio/Subs/Quality, settings, IntroDB skip, next-episode chip.

## Root cause

`DesktopNativePlayerScreen` shipped as a thin Exo sibling for seek/progress (R107-A22 baseline) without the full MediaKit overlay surface. Props for providers/sources/magnet were never passed from `PlayerScreen`.

## Notes

- Audio / Subs / Quality / desktop OS PiP are **chrome-present toast stubs** — track selection and MediaKit-only PiP remain open in [532](../532-[open]-desktop-native-track-apis-pip.md).
- Magnet / torrent from Sources remounts or toasts toward MediaKit (native hard-block policy).
- Same-engine source switch remounts via `PlayerScreen._switchPlayer` `setState` + `ValueKey`.

## Links

- [RFC-107](../../rfc/107-[open]-iptv-multi-engine-avplayer-vlc.md) — R107-A25 full chrome
- [532](../532-[open]-desktop-native-track-apis-pip.md) — native track APIs + desktop PiP
