# 361 — Live Sports MediaKit soft-reopen reconnect storm

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · MediaKit · watchdog / recovery

**Related:** [148](../148-[open]-iptv-live-edge-snap-reconnect-loop.md) · [295](295-[fixed]-mediakit-live-vt-hold-no-golive.md) · [359](359-[fixed]-live-sports-stremio-vt-hold-corrupt-frames.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I361-T01 | MediaKit live watchdog: early-return (no soft-reopen detectors) — same as IPTV RFC-113 | ✅ |
| 2 | I361-T02 | Wire `completed` / socket / error → silent grace → goLive (cap + throttle) | ✅ |
| 3 | I361-T03 | Disable MediaKit live-edge snap + post-open jump; Reload → goLive | ✅ |
| 4 | I361-T04 | VT / hw→sw past cold open → grace→goLive (keeps I359 recovery; no soft-reopen ladder) | ✅ |
| 5 | I361-T05 | Issue + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I361-A01 | Desktop Live Sports Xtream (Auto): channel plays 5+ min without `recovery (#1) buffering 5s, cache empty` → `direct open` loop | ⬜ |
| 2 | I361-A02 | Real dead feed still reconnects via grace→goLive (banner, then ended after attempts) — not infinite `#1` | ⬜ |

---

## Summary

**Symptom:** Live Sports Xtream (`Auto` → `stall`) logged forever:

`[IPTV Watchdog] recovery (#1) buffering 5s, cache empty` → `direct open` → `healthy streak - resetting retries` → `#1` again.

**Root cause:** Live Sports MediaKit kept v1.5.36 soft-reopen detectors after IPTV MediaKit moved to grace→goLive (RFC-113 / ipdigi). Stall mode treats empty Buffering at 5s as dead; healthy streak resets retries so the ladder never escalates.

**Root fix:** Live Sports MediaKit matches IPTV — lavf reconnect first, then capped goLive. Soft-reopen / live-edge snap no longer run on that path. VT past cold open still reconnects ([359](359-[fixed]-live-sports-stremio-vt-hold-corrupt-frames.md)) via grace→goLive instead of the soft-reopen ladder.
