# 081 — macOS quit SIGSEGV in mpv `*/demux` (`msg_wakeup`)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `AppDelegate.swift` · `bootstrap.dart` · `teardownMediaKitPlayer` · media_kit / mpv  
**Reported:** 2026-07-18  
**Fixed:** 2026-07-18

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance (manual macOS smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I81-T01 | `applicationShouldTerminate` → Flutter `prepareQuit` (⌘Q / Quit menu) | ✅ |
| 2 | I81-T02 | Shared `_runDesktopQuit` for red-X + ⌘Q; macOS `replyReadyToTerminate` | ✅ |
| 3 | I81-T03 | Quieter mpv teardown + longer stop settle before dispose (demux / wakeup race) | ✅ |
| 4 | I81-T04 | Longer macOS shutdown timeout + post-dispose grace | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I81-A01 | macOS: quit via red-X and ⌘Q while idle / after playback / mid-stream — process exits without demux SIGSEGV | ⬜ |

---

## Summary

**1.2.308 macOS** crashed almost every quit with `EXC_BAD_ACCESS` on thread `*/demux`:

`av_log` → `mp_msg_av_log_callback` → `mp_msg` → `msg_wakeup` → invalid PC (freed trampoline).

Main thread was in `NSApplication terminate:` / Flutter join. `*/mpv core` was in `demux_free` → `_pthread_join`.

**Root causes (two layers):**

1. **⌘Q bypass** — Quit menu calls `NSApp.terminate` and never runs Flutter `onWindowClose`, so mpv was still demuxing while Flutter tore down.
2. **stop/dispose race** — Timed `player.stop()` (800ms) could time out in Dart while mpv still ran `demux_free`; immediate `dispose()` cleared the `msg_wakeup` NativeCallable; demux then logged through a dead pointer.

**Fix:** Intercept terminate until Flutter finishes timed media_kit + engine shutdown; quiet mpv logs; give stop longer to finish before dispose; longer macOS grace before AppKit replies ready to terminate.

Related: [062](fixed/062-[fixed]-windows-quit-freeze-unbounded-mpv-teardown.md) (Windows freeze / timed teardown) — that path did not cover macOS ⌘Q.

## Verify

1. macOS build with this change
2. Play a stream, then Quit (⌘Q) and close via red-X — no Crash Reporter demux SIGSEGV
3. Idle quit (no player) — still exits cleanly
