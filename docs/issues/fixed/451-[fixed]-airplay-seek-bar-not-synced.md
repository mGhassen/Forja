# 451 — AirPlay seek bar not synced while casting

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**RFC:** [RFC-005](../../rfc/005-[partial]-casting.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0/1** acceptance (device QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I451-T01 | Native iOS + macOS AirPlay: periodic position events + `seek` channel | ✅ |
| 2 | I451-T02 | CastingService `position` / `seekIfCasting` + `CastHandoff.onPosition` | ✅ |
| 3 | I451-T03 | Desktop / mobile / Live Sports: mirror cast playhead; route scrub to AirPlay | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I451-A01 | Cast VOD to Apple TV; Forja seek bar advances; scrub in Forja seeks the TV | ⬜ |

---

## Problem

While AirPlay was active, the in-app seek bar stayed frozen (local player paused). Scrubbing in Forja did not move the TV. Desktop felt worse than phone because Mac chrome stays on screen and system Now Playing is less of a substitute.

## Root cause

AirPlay uses a separate muted `AVPlayer`. Events were only `active` / `inactive` / `error` — no live position, no seek. The seek bar followed paused media_kit.

## Fix

Native channels emit `position` ~2 Hz while external playback is active and accept `seek`. CastingService forwards ticks to `CastHandoff.onPosition` and `seekIfCasting` from player scrub paths. Local position listeners ignore updates while AirPlay is active.
