# 524 — Phone MediaKit: opening a stream kills the process

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android phone · MediaKit · VOD open  
**Reported:** 2026-10-29 (emulator `mobile` flavor, anime Anizone HLS)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Play a VOD stream on the Android phone app (MediaKit). Log shows `[OpenPipeline] branch → openDirect`, then `Lost connection to device` — process (or emulator) dies. A yellow `RenderFlex overflowed` on the phone source chip appeared in the same session but did not kill the process.

## Root cause

Phone MediaKit safe-mode forces software decode (`hwdec=no`) but still opened with the ATV-sized VOD RAM window: `PlayerConfiguration.bufferSize=128MiB` plus `demuxer-max-bytes=128MiB` / `demuxer-max-back-bytes=40MiB` (`mobile_player_lifecycle.dart`, `mobile_player_playback.dart`). Same class as ATV VOD fat-cache process death ([163](../163-[open]-android-tv-iptv-vod-live-profile.md)).

Secondary (layout only): `PlayerStreamPickerButton` painted a labeled Row inside a ~64 dp `Flexible` slot without collapsing to icon-only.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I524-T01 | Phone safe-mode: lean Player `bufferSize` 32 MiB + demuxer 32 MiB / 16 MiB back / shorter cache-secs | ✅ |
| 2 | I524-T02 | Phone source / stream-picker chip: collapse below `sourceLabeledMinWidth`; bound Row + `Expanded` so tight slots never overflow | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I524-A01 | Phone `mobile` flavor: open anime HLS (e.g. Anizone) — plays; no `Lost connection` | ⬜ |
| 2 | I524-A02 | Phone landscape transport: source chip never yellow-overflows at ~64 dp Flexible width | ⬜ |

## Links

- [163](../163-[open]-android-tv-iptv-vod-live-profile.md) — ATV VOD fat MediaKit cache / process death
- [187](../187-[open]-android-tv-mediakit-vod-cache-empty.md) — why ATV keeps the fat 128 MiB window (unchanged)
- [128](../128-[open]-android-tv-iptv-mediakit-exit-anr.md) — MediaKit surface teardown (separate)
