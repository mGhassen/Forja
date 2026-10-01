# 364 — Desktop focus / resume sync storm (hitch on every Cmd-Tab)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `app/bootstrap.dart` · desktop session keep-alive  
**Reported:** 2026-09-24  
**Fixed:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** fix · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I364-T01 | Coalesce `onWindowFocus` / `onWindowRestore` / lifecycle `resumed` into one wake handler (~400 ms) | ✅ |
| 2 | I364-T02 | Drop `syncFromCloud` / Simkl `fullSync` / `Telemetry.syncAnalyticsIdentity` from focus/resume/restore | ✅ |
| 3 | I364-T03 | Wake path only calls `ensureFreshAccessToken` (no full `refreshSession`); skip when away &lt; 2 min | ✅ |
| 4 | I364-T04 | Stamp leave time on blur / inactive / hidden / paused so brief alt-tabs do nothing | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I364-A01 | Desktop: Cmd-Tab away &lt; 2 min and back — no cloud pull / Simkl / shell hitch | ⬜ |
| 2 | I364-A02 | Desktop left open hours: keep-alive still refreshes JWT; near-expiry wake still calls `ensureFreshAccessToken` | ⬜ |

---

## Summary

Every desktop foreground return ran session refresh + full cloud soft-pull + Simkl + telemetry (focus, restore, and often `resumed` together). That made alt-tab feel like a reload / freeze. Cloud soft-pull stays on **tab switch** and cold start; Simkl stays **post-splash**; JWT long-idle stays on the **12 min keep-alive** ([106](../106-[open]-desktop-session-profile-chrome-desync.md)).

**Symptom fix:** lean coalesced wake. **Root fix:** same — removed the unnecessary focus cascade (not a hide).

**Note:** A hard macOS UI freeze with no frames until Dock click is Flutter engine [flutter#155977](https://github.com/flutter/flutter/issues/155977) — app workaround in [367](../367-[workaround]-macos-cmd-tab-frame-freeze.md); root upgrade in [368](../368-[open]-flutter-macos-occlusion-resume-upgrade.md).

**Related:** [106](../106-[open]-desktop-session-profile-chrome-desync.md)
