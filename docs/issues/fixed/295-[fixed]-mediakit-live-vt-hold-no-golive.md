# 295 — MediaKit live holds on VT decode fail instead of goLive

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** IPTV / Live Sports · MediaKit · macOS VideoToolbox

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I295-T01 | MediaKit live mpv log: VT / hw accelerator fail → grace → goLive (not healthy hold) | ✅ |
| 2 | I295-T02 | `_forceSoftwareDecode` live path: grace→goLive (not `_triggerRecovery` healthy-hold) | ✅ |
| 3 | I295-T03 | Hw-decode grace end always goLive (playhead/audio can advance with black picture) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I295-A01 | Stremio / live HLS that paints black with `hardware accelerator failed` / `-12909` auto-reconnects (~6s) without manual reload | ⬜ |
| 2 | I295-A02 | Same URL that plays in Stremio after Forja open — Forja recovers without user Reload | ⬜ |

---

## Summary

MediaKit live saw VideoToolbox fail (`vt decoder cb` / `hardware accelerator failed`) and **held** while demux kept feeding — `_streamWorking` stayed true, so nothing recovered. Manual reload = `goLive` (stop+open) and worked. Stremio played the same URL.

Root: log listener + live `_forceSoftwareDecode` refused SW (correct) but never scheduled grace→goLive (comment said they would). Issue 148 T18 held VT fails expecting empty-cache detectors; MediaKit live watchdog does not run those detectors.

**Fix:** schedule the same grace→goLive path as socket/completed recovery; hw-decode grace always reopens (keep HW).
