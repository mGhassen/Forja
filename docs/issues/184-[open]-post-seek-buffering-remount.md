# 184 — Post-seek BUFFERING: remount same URL at seek target

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/` (MediaKit + Exo VOD)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I184-T01 | Shared `PostSeekStallWatchdog` — BUFFERING ≥10s after user seek → remount once | ✅ |
| 2 | I184-T02 | MediaKit mobile + desktop: arm on `_seekTo`, remount via `remountPlayerStreamAtPosition` | ✅ |
| 3 | I184-T03 | ExoPlayer: arm on ±10s / scrub, remount via `ExoPlayerBridge.open` at seek target | ✅ |
| 4 | I184-T04 | Unit test: remount once per seek; cancel when buffering clears / position advances | ✅ |
| 5 | I184-T05 | Also remount on silent freeze (buffering=false, position stuck) — MediaKit primary | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I184-A01 | Videasy (or similar HLS) on MediaKit: +10s that freezes (buffering or silent) remounts and resumes near the seek target within ~15s | ⬜ |
| 2 | I184-A02 | Healthy seek (brief buffer then play) does not remount; pause after seek does not remount | ⬜ |

---

## Summary

User seek (±10s / scrub) only called `player.seek` / Exo `seekTo`. UI mirrored `buffering` forever when HLS/CDN stalled after the seek. Mid-watch Auto hop only runs on **fatal** errors — stuck BUFFERING never failed over. HTTP errors mid-play are ignored by design.

**Root fix (option 1):** after a user seek, if playback does not resume within ≥10s — either BUFFERING stays true **or** MediaKit sits frozen with buffering=false and position stuck — remount the **same** play URL once at the seek target (no provider hop). Pause cancels. Torrents / loopback skipped. New seek re-arms.

---

## Related

- [153](153-[open]-kisskh-hls-4k-indefinite-buffer.md) — scrub BUFFERING (PNG HLS; remount path abandoned there)
- [175](175-[open]-mid-watch-auto-failover.md) — fatal mid-watch Auto hop (different trigger)
- [Player](../features/playback/player.md)
