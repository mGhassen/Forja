# 387 — IPTV goLive opens twice and ends the live stream

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV · Live Sports · MediaKit

**Related:** [RFC-113](../rfc/113-[open]-iptv-mediakit-direct-reconnect.md) · [362](fixed/362-[fixed]-iptv-mediakit-log-eof-grace-storm.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** tasks · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I387-T01 | IPTV MediaKit goLive: 2s slot after stop, stable timer confirms only, one poll, cold retry instead of Stream ended | ✅ |
| 2 | I387-T02 | Live Sports MediaKit: same goLive sequencer | ✅ |
| 3 | I387-T03 | Issue + changelog + RFC-113 C15 / A11 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I387-A01 | Desktop Xtream `.ts`: Dart `completed` reopens once after the slot gap; a refused open shows the 15s retry banner and does not print two `Failed to open` back to back or `goLive exhausted — ended` | ⬜ |
| 2 | I387-A02 | Premature-EOF mpv logs still do not start goLive while the demuxer is feeding ([362](fixed/362-[fixed]-iptv-mediakit-log-eof-grace-storm.md)) | ⬜ |

---

## Summary

Xtream closed a live `.ts`. Lavf did not restitch, so Dart `completed` started goLive. `stop` then opened the same URL immediately, and the 1.5s stable timer opened it again. The panel still held the one connection, both opens failed, and both timers set “Stream ended.”

**Root fix:** one sequencer. After `stop`, wait 2s, then one open. The stable timer only confirms playback. The poll is the only next open. A failed burst uses the existing 15s cold retry. `forceLiveRefresh` stays off. Lavf log ignore from 362 stays.
