# 388 — IPTV reconnect replays the last few seconds

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV · Live · MediaKit

**Related:** [RFC-113](../rfc/113-[open]-iptv-mediakit-direct-reconnect.md) · [362](fixed/362-[fixed]-iptv-mediakit-log-eof-grace-storm.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** tasks · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I388-T01 | Resume during grace so `keep-open` pause is not treated as a dead stream | ✅ |
| 2 | I388-T02 | After a rewind or goLive, seek by demuxer cushion (no drop-buffers) | ✅ |
| 3 | I388-T03 | Same path on Live Sports MediaKit | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I388-A01 | Desktop Xtream `.ts`: after `live glitch (completed)` → goLive, the channel does not replay the previous ~15s | ⬜ |

---

## Summary

Xtream closed a progressive `.ts` (`Stream ends prematurely`, unknown length). mpv fired `completed`. `keep-open=always` paused, so the 6s grace never saw the playhead move and called goLive. The new GET starts inside the panel archive, so the user rewatched the last ~15s.

**Root fix:** resume play at the start of grace. If the playhead jumps backward, skip the buffered archive and do not reopen again. A real goLive does the same skip after the new open. No `drop-buffers`.

**Symptom fix:** none.

**Workaround:** no.
