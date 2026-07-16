# 074 — VOD EOF sticks the seek bar (no scrub / restart)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player`, VOD / anime / drama streams

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **3 / 4** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I74-T01 | Set mpv `keep-open=yes` on VOD desktop/mobile so EOF keeps the last frame | ✅ |
| 2 | I74-T02 | Seek helper updates position + resumes play when scrubbing away from EOF | ✅ |
| 3 | I74-T03 | Preserve mid-playback + session-first confirm across source switches / late reconfirm | ✅ |
| 4 | I74-T04 | Unit: session age after late reconfirm counts as natural end / persist | ✅ |
| 5 | I74-T05 | Wire UI/keyboard ±10s + seek bar through the EOF-safe seek helper | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I74-A01 | Unit: mid-watched session age ≥45s after late reconfirm is a natural end | ✅ |
| 2 | I74-A02 | Unit: near-end progress persists when mid session is old enough despite fresh open confirm | ✅ |
| 3 | I74-A03 | Unit: early EOF without mid still rejected | ✅ |
| 4 | I74-A04 | Manual: watch to end → scrub back / restart works; bar updates | ⬜ |

---

## Summary

When a VOD title reached EOF, mpv went idle without `keep-open`, so the progress bar stopped updating and seeks no-op’d — users could not scrub back or start again.

Separately, issue 072’s early-EOF guards used the *latest* confirm timestamp and cleared mid-playback on every unconfirm. A late source switch / re-open near credits reset `confirmedFor` to a few seconds, so a real ~24 min finish logged `Ignoring abortive completed` and skipped watch-history near-end saves.

Root fix: keep the last frame open at EOF, seek through a helper that refreshes the bar and resumes when leaving the end, and measure natural-end / persist grace from the first confirm of the episode session once mid-playback was observed.

## Related

- [072](072-[fixed]-torrent-early-eof-false-completed-autonext.md) — early-EOF / auto-next guards (still required)
- Changelog `1.2.x` — seek-after-EOF + session natural-end
