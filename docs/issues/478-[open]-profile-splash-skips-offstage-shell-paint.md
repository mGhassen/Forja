# 478 — Profile splash dismisses before Offstage shell paint

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · desktop · cold start / profile splash  
**Reported:** 2026-10-25 (TV first launch — avatar splash ends, Home freezes on TMDB rails)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance (device QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

After picking a profile on TV/desktop, the avatar splash finishes and the shell appears, then the UI freezes while Home TMDB rails load (logs: `[MainScreen] Built tab: home` then `action=rail` 13–19s). Intro logo splash mounts `MainScreen` under `Offstage` during warm; the profile path set `ShellBus.splashDismissed` and skipped that, so Home mounted cold after dismiss.

## Root cause

`DesktopStartupGate` used to call `_enterShellAfterProfileSplash` → `splashDismissed=true` → `SplashScreen` skip path (no overlay). Profile splash only awaited packs + hub **feed** prefetch — not Offstage first paint. Below-fold `LazyViewportGate` rails then stampeded on the interactive shell.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I478-T01 | Mount `MainScreen` under avatar splash (Offstage) after profile select; flip `offstage` on same Stack to reveal | ✅ |
| 2 | I478-T02 | Gate: no splashDismissed skip remount; guest/packs still use intro SplashScreen warm; no default-tab re-arm on reveal | ✅ |
| 3 | I478-T03 | Changelog + issue tracking | ✅ |
| 4 | I478-T04 | Hold avatar ≥3s after Offstage mount so settings sync cannot zero the paint floor | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I478-A01 | TV: pick profile → avatar splash stays up while Home first paint warms under Offstage → reveal without multi-second freeze | ⬜ |
| 2 | I478-A02 | Guest / restored-session intro splash still Offstage-warms (no regression) | ⬜ |

## Links

- [RFC-018](../rfc/018-[draft]-startup-splash-home.md) — dismiss when Home ready / Offstage warm
- [RFC-017](../rfc/017-[open]-deferred-engine-boot.md) — splash awaits packs + hub prefetch
