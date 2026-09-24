# 362 — IPTV MediaKit: ffmpeg log EOF drove grace/goLive storm

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** IPTV · Live · MediaKit · macOS / desktop

**Related:** [RFC-113](../../rfc/113-[open]-iptv-mediakit-direct-reconnect.md) · [357](../357-[open]-iptv-vod-mediakit-ipdigi-parity.md) · [148](../148-[open]-iptv-live-edge-snap-reconnect-loop.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I362-T01 | IPTV MediaKit: do not map mpv log `ends prematurely` / reset / timeout → `_noteSocketTrouble` / grace | ✅ |
| 2 | I362-T02 | Live Sports MediaKit: same log ignore (completed/error still grace→goLive) | ✅ |
| 3 | I362-T03 | Issue + changelog + RFC-113 C14 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I362-A01 | macOS IPTV Xtream progressive TS: minutes of play with `mpv log (lavf owns): … ends prematurely` and **no** `live glitch (socket …)` / goLive every ~10s | ⬜ |
| 2 | I362-A02 | Real dead feed still recovers via Dart `completed`/`error` → grace → goLive (banner) | ⬜ |

---

## Summary

Xtream live progressive TS often closes the HTTP socket mid-broadcast (`Stream ends prematurely … should be 18446744073709551615`). ffmpeg lavf reconnect stitches that inside libavformat and still **prints** the line. **ipdigi** never listens to `player.stream.log` for recovery — only `completed` / `error`.

Forja mapped those log lines to `_noteSocketTrouble` → 6s grace → occasional `goLive`, plus VT ignore spam (`ignoring transient hw fail`). Symptom: reconnect churn every ~10s while the stream was still feeding.

**Root fix:** ignore socket-style ffmpeg log lines for recovery (debug only). Keep grace→goLive on Dart `completed` / `error` (ipdigi parity).

---
