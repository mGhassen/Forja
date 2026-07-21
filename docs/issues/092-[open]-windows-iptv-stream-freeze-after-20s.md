# 092 — Windows IPTV stream freezes after ~20s (no reconnect)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `iptv_pt_player_engine.dart` · `iptv_pt_player_screen.dart` · media_kit / libmpv Windows  
**Reported:** 2026-07-21

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I92-T01 | Windows IPTV: force `hwdec=no` + `vd-lavc-dr=no` from boot | ✅ |
| 2 | I92-T02 | Soft reopen first on Windows stalls; hard recreate only after retry > 4; timed `teardownMediaKitPlayer` | ✅ |
| 3 | I92-T03 | Watchdog: position-freeze recovery even while buffering flickers (so “Reconnecting…” can fire) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I92-A01 | Windows release: live IPTV channel plays past 2+ minutes without last-frame freeze; if upstream dies, “Reconnecting…” appears | ⬜ |

---

## Summary

**Symptom (1.2.365):** Live IPTV on Windows plays ~15–20s, then video + audio stick on the last frame. App UI stays responsive. No “Reconnecting…” banner. Movie/TV player on the same box is fine. Reproducible every play.

**Root (two layers):**

1. **Windows HW decode / D3D11 direct rendering** on live feeds — plays through the ~20s readahead window then sticks the surface. VOD already had software-decode fallback; IPTV did not (only macOS VT log matchers).
2. **Watchdog hole** — detector 2 required `!buffering`. Windows live feeds flicker `buffering` while frozen, resetting detector 1’s timer, so recovery never ran and no banner appeared.

**Fix:** Force software decode on Windows IPTV; prefer soft reopen over hard `_recreatePlayer` on early stalls; use timed `teardownMediaKitPlayer` (same as issue 062); drop the buffering gate on position-freeze recovery.

**Related:** [062](fixed/062-[fixed]-windows-quit-freeze-unbounded-mpv-teardown.md) · prior report in chat (crash after 10–15s / logout “fix”)

## Verify

1. Windows build with this change
2. Play a live Xtream channel 2+ minutes
3. Kill upstream or wait for a bad segment — expect “Reconnecting…”, not a permanent frozen frame
