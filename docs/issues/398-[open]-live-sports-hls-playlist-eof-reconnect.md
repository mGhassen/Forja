# 398 — Live Sports HLS playlist reconnects at EOF and never plays

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · MediaKit · Streamic

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 1** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I398-T01 | Live Sports HLS (`*.m3u8`, `/hls-proxy`) omits `reconnect_at_eof`; progressive `.ts` keeps it. Set `stream-lavf-o` before open. | ✅ |

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

`liveSportsStreamLavfO` drops `reconnect_at_eof` when `iptvUrlLooksLikeHls` is true. Applied before `player.open`.

## Root fix

Same change. The HLS demuxer must see playlist EOF so it can reload and open segments.

## Workaround

No.
