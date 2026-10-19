# 449 — Live player multi-tap stacks MediaKit / freezes UI

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · IPTV native player · Providers open

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I449-T01 | Single-flight gate on Live Sports / IPTV `open` (shared until route pops) | ✅ |
| 2 | I449-T02 | `_scheduleHideControls` returns when unmounted before reading `context` | ✅ |
| 3 | I449-T03 | Boot paths skip hide-controls / chrome focus after dispose mid-open | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I449-A01 | Rapid multi-tap a Live Sports Providers row → one player, stream opens, no UI freeze / unmounted exception | ⬜ |

---

## Summary

Rapid taps on a Live Sports (or IPTV) Providers row pushed several native player routes. Each unlocked (`timstreams` resolve) and booted MediaKit in parallel — UI froze and the stream never settled. A disposed boot still called `_scheduleHideControls`, which read `context` and threw.

**Root fix:** `NativePlayerOpenGate` drops overlapping opens until the first session pops; mount guards on hide-controls and post-await boot.

**Related:** [209](209-[fixed]-forja-sports-stalker-create-link-all-channels.md) (Stalker pre-open gen; same stack symptom)
