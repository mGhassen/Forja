# 198 — MediaKit resume / server switch starts at 0:00

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** player / MediaKit / HLS resume

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0/2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I198-T01 | `openPlayerStream` sets mpv `start` before open; clear after | ✅ |
| 2 | I198-T02 | Initial resume + torrent open use `startAt` + `ensureOpenedNearPosition` | ✅ |
| 3 | I198-T03 | In-player server / provider / quality switch preserve playhead the same way | ✅ |
| 4 | I198-T04 | Mid-watch Auto re-init passes live playhead (`seekOverride`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I198-A01 | Resume a movie/anime/drama mid-watch (API HLS) opens near saved time, not 0:00 | ⬜ |
| 2 | I198-A02 | Same session: change Source / provider / quality keeps current time | ⬜ |

---

## Summary

MediaKit opened streams at 0:00 then called `player.seek` after open. For HLS that seek often no-oped while duration was still unknown, and `_hasInitialSeek` latched so the duration listener never retried. In-player server switches had the same post-open seek pattern.

**Root fix:** open with mpv `start` (same idea as post-seek remount), then hard-seek only if still far from target. Auto re-init mid-watch passes the live playhead instead of only history `startPosition`.

ExoPlayer already passed `startMs` on setMedia — unchanged.

## Related

- `apps/forja/lib/shared/player/player/utils.dart` — `openPlayerStream.startAt`, `ensureOpenedNearPosition`
- [184](../184-[open]-post-seek-buffering-remount.md) — remount already used mpv `start`
