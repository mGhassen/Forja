# 398 — Live Sports HLS playlist reconnects at EOF and never plays

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · MediaKit · Streamic

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I398-T01 | Live Sports HLS (`*.m3u8`, `/hls-proxy`) omits `reconnect_at_eof`; progressive `.ts` keeps it. Set `stream-lavf-o` before open. | ✅ |
| 2 | I398-T02 | IPTV player (hub player setting IPTV) uses the same HLS omission in `iptvStreamLavfO`, re-applied after `open`. | ✅ |
| 3 | I398-T03 | Revert I398-T02. IPTV `iptvStreamLavfO` stays on for HLS and progressive. Live Sports player only. | ✅ |
| 4 | I398-T04 | Live Sports HLS also sets `reconnect=0` and `reconnect_streamed=0`. `reconnect=1` still range-resumes a short playlist when the length is unknown. IPTV string unchanged. | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I398-A01 | macOS Live Sports Streamic (picture-segment HLS via `/hls-proxy`): picture starts. Log is not `Will reconnect at <playlist size> … End of file` stuck on one offset. | ⬜ |

---

## Summary

Streamic unlock returns a short HLS playlist (proxied rewrite ~4 KB). Live Sports always set `reconnect_at_eof=1`. ffmpeg treated playlist EOF as a live socket close and Range-reconnected at that byte with delay 0, so segments were never fetched.

Progressive Xtream `.ts` still uses `reconnect_at_eof`.

---

## Symptom fix

`liveSportsStreamLavfO` drops `reconnect`, `reconnect_streamed`, and `reconnect_at_eof` for HLS. Network and HTTP error retries stay. IPTV `iptvStreamLavfO` is unchanged.

## Root fix

Same change. Dropping only `reconnect_at_eof` left `reconnect=1`, which still resumes a short playlist at that byte when the length is unknown. Playback on device is still the acceptance check.

## Workaround

No.
