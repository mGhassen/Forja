# 453 — AirPlay drops on next episode

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**RFC:** [RFC-005](../../rfc/005-[partial]-casting.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0/1** acceptance (device QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I453-T01 | Native AirPlay `replace` — new URL without dropping external route | ✅ |
| 2 | I453-T02 | CastingService retain across player replace + `replaceActiveCast` | ✅ |
| 3 | I453-T03 | `AppRouter.openPlayer` retain; desktop/mobile rebind on playback confirm | ✅ |
| 4 | I453-T04 | Suppress local **Buffering…** while AirPlay owns playback | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I453-A01 | Cast VOD, tap Next Episode; TV plays the next episode without reopening AirPlay | ⬜ |

---

## Problem

Next episode replaced the player route; `dispose` called `stopCasting()`, so AirPlay ended and the user had to cast again.

## Fix

In-player `openPlayer` calls `retainAcrossPlayerHandoff`. Dispose skips AirPlay teardown once. The new player’s confirmed open calls `replaceActiveCast` so the same TV session loads the new URL.
