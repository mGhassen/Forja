# 498 — MediaKit HLS A/V desync after buffer hiccup

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Desktop / Android TV MediaKit · catalog VOD · anime HLS  
**Reported:** 2026-10-26 (desktop MediaKit; also ATV MediaKit — animekai / hianime / megaplay; KissKh OK)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Anime MegaPlay-family streams: after ~10s a brief freeze → video speeds / jumps → sound stays permanently out of sync. Desktop MediaKit always; Android TV MediaKit sometimes. KissKh (and similar) stay in sync.

## Root cause

- **Desktop catalog VOD:** `video-sync=display-resample` + `cache-pause=no` + interpolation — after an HLS underrun, video races the display clock and never re-locks to audio (`desktop_player_playback.dart`).
- **ATV/mobile catalog VOD:** already `video-sync=audio` + `cache-pause=yes`, but missing `initial-audio-sync=yes` (IPTV VOD already sets it) so cache-pause refill / lavf reconnect can leave A/V offset.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I498-T01 | Desktop network VOD: `video-sync=audio`, pause-to-refill, no interpolation, `initial-audio-sync` | ✅ |
| 2 | I498-T02 | Keep desktop torrent/local on display-resample + play-through | ✅ |
| 3 | I498-T03 | Mobile/ATV catalog MediaKit: `initial-audio-sync=yes` | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I498-A01 | Desktop MediaKit: MegaPlay anime ~2+ min — hiccup may BUFFER briefly; lipsync stays locked | ⬜ |
| 2 | I498-A02 | Android TV MediaKit: same MegaPlay title — no permanent A/V desync after a refill | ⬜ |

## Links

- [187](../187-[open]-android-tv-mediakit-vod-cache-empty.md) — ATV VOD `cache-pause=yes`
- [357](../357-[open]-iptv-vod-mediakit-ipdigi-parity.md) — IPTV VOD `initial-audio-sync`
- [510](../510-[open]-megaplay-pngstrip-vod-prefetch-desync.md) — MegaPlay `pngWrapTs` strip prefetch was warming VOD **tail**; A01 still fails until that lands
