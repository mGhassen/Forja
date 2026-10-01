# 348 — Player audio switch silent until scrub back

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** MediaKit VOD · `selectPlayerAudioTrack`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I348-T01 | After `aid` change, nudge playhead back (~750ms) instead of same-position seek | ✅ |
| 2 | I348-T02 | Prefer mpv relative `seek` for demux rebind; absolute fallback | ✅ |
| 3 | I348-T03 | Unit + changelog + audio feature note | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I348-A01 | Unit: resync target rewinds under nudge; stays under Peakstorm remount delta | ✅ |
| 2 | I348-A02 | App: pick another audio track mid-play — audio returns on the new language without scrubbing | ⬜ |

---

## Summary

Changing audio in the player set mpv `aid` then sought to the **same** playhead. That absolute seek is a no-op, so demux/AO stayed silent until the user scrubbed **backward**. The menu check marked the new track selected, so it looked like a switch “worked” with no sound.

### Fix

- After track select, rewind ~750ms (or to 0 near the start) so mpv actually rebinds
- Prefer relative `seek` on NativePlayer; fall back to absolute
- Keep the nudge under Peakstorm fMP4 remount delta (3s)

### Related

- [audio-tracks](../../features/playback/audio-tracks.md)  
- Changelog 1.4.81 (same-position resync — insufficient)
