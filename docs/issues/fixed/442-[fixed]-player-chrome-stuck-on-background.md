# 442 — Player chrome stuck when app leaves foreground

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** player chrome · lifecycle · MediaKit / Exo / IPTV / Live Sports

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6 / 6** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I442-T01 | Mobile MediaKit: hide chrome on `paused` / `hidden` / `detached` | ✅ |
| 2 | I442-T02 | Desktop MediaKit: `_hideChromeIntentional` on background (skip PiP / mini) | ✅ |
| 3 | I442-T03 | ExoPlayer: hide chrome on background | ✅ |
| 4 | I442-T04 | IPTV portal player: hide chrome on background | ✅ |
| 5 | I442-T05 | Live Sports player: hide chrome on background | ✅ |
| 6 | I442-T06 | On `resumed`, reveal chrome + clear desktop hover suppress (return = activity) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I442-A01 | Android TV / phone: leave player (Home / switcher) with chrome up → chrome gone in recents / on return | ⬜ |
| 2 | I442-A02 | Intentional pause (Space / Play) still keeps chrome visible until idle-hide while playing resumes | ⬜ |
| 3 | I442-A03 | Desktop: leave + click back → chrome shows; idle still hides after timer | ⬜ |

---

## Summary

Idle-hide arms only while `_isPlaying` / `_isPlayingNotifier` is true. Leaving foreground pauses playback (ATV always; phone/desktop when Play in background is off) and freezes Dart timers — chrome stayed painted.

**Root fix:** on `AppLifecycleState.paused` / `hidden` / `detached`, cancel the hide timer and hide chrome immediately (PiP / in-app mini skipped). Intentional user pause still keeps chrome (playing-gate unchanged).

---

## Related

- [Player](../../features/playback/player.md)
