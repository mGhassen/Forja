# 440 — MediaKit VOD scrub: keyframe seek (cut multi-second BUFFERING)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/screens/` (MediaKit desktop + mobile VOD)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I440-T01 | `applyNetworkVodKeyframeSeek` — `hr-seek=no` before network `player.seek` (not torrents) | ✅ |
| 2 | I440-T02 | Desktop + mobile VOD `_configureMpvProperties`: session `hr-seek=no` | ✅ |
| 3 | I440-T03 | Trailer MediaKit configure: same `hr-seek=no` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I440-A01 | macOS MediaKit HLS (any provider): ±10s / scrub BUFFERING feels closer to ~1s than multi-second accurate seek | ⬜ |
| 2 | I440-A02 | Local torrent scrub still Range-seeks (`hr-seek=yes` via seekable promote) | ⬜ |

---

## Summary

Network VOD on MediaKit used mpv’s default / accurate seek path. Every scrub re-decoded from the previous keyframe while HLS refilled → multi-second BUFFERING on all providers (same URL session; not re-unlock). Browser HLS snaps nearer a keyframe and resumes sooner.

**Root fix:** set `hr-seek=no` for network VOD at configure time and again before each non-torrent `player.seek`. Torrents keep accurate/`hr-seek=yes` after seekable promote.

Follow-ups (not this slice): scrub-hover HLS segment prefetch; optional deep-scrub remount-with-`start`.

---

## Related

- [184](184-[open]-post-seek-buffering-remount.md) — stall remount when BUFFERING never clears
- [Player](../features/playback/player.md)
