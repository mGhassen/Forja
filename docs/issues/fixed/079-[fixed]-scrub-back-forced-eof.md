# 079 — Scrub-back forced back to EOF

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player`, VOD / anime HLS

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **3 / 4** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I79-T01 | Suppress early-EOF seek-bar jumps to duration within grace (no mid) | ✅ |
| 2 | I79-T02 | Do not re-pin seek bar / auto-next when UI already scrubbed away from EOF | ✅ |
| 3 | I79-T03 | Ignore stale near-end position reports for 2s after scrub-away; reset fake EOF bar on abortive completed | ✅ |
| 4 | I79-T04 | Unit coverage for suppress / pin / stale-EOF helpers | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I79-A01 | Unit: near-end jump within grace without mid is suppressed | ✅ |
| 2 | I79-A02 | Unit: completed pin skipped when UI position is away from EOF | ✅ |
| 3 | I79-A03 | Unit: stale EOF position ignored for 2s after scrub-away | ✅ |
| 4 | I79-A04 | Manual: early-EOF or real EOF → scrub / −10s leaves the end and keeps playing | ⬜ |

---

## Summary

Dead HLS opens (and keep-open after a real finish) could paint the seek bar at `position == duration`. Scrubbing backward then lost to either:

1. **Early EOF** — demux jumped to duration within ~17s with `mid=false`; bar stuck at 100% while watch-history correctly skipped the poison save.
2. **Completed re-pin** — after a real finish, `completed` re-fired while mpv position was still `0`/end and forced the UI bar back to duration even though the user had already scrubbed away.
3. **Stale position** — near-end reports arrived after scrub-away and yanked the bar back to the end.

Root fix: suppress early-EOF bar jumps, only pin at EOF when the UI is still at the end, and ignore stale EOF position events briefly after scrub-away.

## Related

- [072](072-[fixed]-torrent-early-eof-false-completed-autonext.md) — early-EOF / auto-next guards
- [074](074-[fixed]-vod-eof-seek-bar-stuck.md) — keep-open + seek-after-EOF helper
