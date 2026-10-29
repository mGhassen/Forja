# 119 — Android TV: double Back on nav / double Exit to quit

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · shell Back / Exit · `ShellTvAppExit`  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I119-T01 | `ShellTvAppExit` double-confirm + `PlatformChannel.exitAppCompletely` (finishAndRemoveTask + kill) | ✅ |
| 2 | I119-T02 | Nav rail Back: first arms toast, second within 2s quits (no page-restore loop) | ✅ |
| 3 | I119-T03 | Remote Exit (Escape) separate from Back — double-confirm quit from anywhere | ✅ |
| 4 | I119-T04 | Coordinator + back-handler tests for nav double-Back and Exit | ✅ |
| 5 | I119-T05 | Android TV power / `SCREEN_OFF` / `SHUTDOWN` → same `exitAppCompletely` as double Back | ✅ |
| 6 | I119-T06 | Reverse T05 — do not quit on power / screen-off / shutdown ([518](fixed/518-[fixed]-android-tv-power-kills-xiaomi-bounce.md)) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I119-A01 | Leanback: Back to nav → Back → toast → Back again exits to launcher; reopen is cold | ⬜ |
| 2 | I119-A02 | Leanback: Exit (Escape) twice from a tab page exits; single Back still navigates only | ⬜ |
| 3 | I119-A03 | Physical Android TV: remote power while Forja is open → launcher on power-on (cold next open); Home still does not quit | ⬜ |
| 4 | I119-A04 | Physical Android TV: remote power stands the box down without Forja bouncing back; quit remains double-Back / Exit only ([518](fixed/518-[fixed]-android-tv-power-kills-xiaomi-bounce.md) A01) | ⬜ |

---

## Summary

TV Back never finished `MainActivity` (by design). That left no in-app quit path: Back on the nav rail restored page focus forever. Remote Exit (Escape) was wired like Back.

**Fix:** Back stays level-aware, except on the **nav rail** where the first Back arms exit and the second within 2s quits. Remote **Exit** is a separate double-confirm quit from anywhere. **Power / standby is the system’s job** — Forja must not consume power keys or kill on `SCREEN_OFF` / `SHUTDOWN` (T05 caused Xiaomi standby bounce; reversed in [518](fixed/518-[fixed]-android-tv-power-kills-xiaomi-bounce.md)). Phone lock/sleep is unchanged. Home still does not quit.

## Related

- [RFC-028](../rfc/028-[draft]-adaptive-shell-profiles.md) — TV shell Back policy (`R28-A29`) · power must not quit (`R28-A32`)
- [518](fixed/518-[fixed]-android-tv-power-kills-xiaomi-bounce.md) — Xiaomi power bounce root fix
- [platforms](../features/getting-started/platforms.md) · [navigation](../features/getting-started/navigation.md)
