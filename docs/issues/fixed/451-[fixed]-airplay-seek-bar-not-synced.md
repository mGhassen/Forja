# 451 — AirPlay seek bar not synced while casting

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**RFC:** [RFC-005](../../rfc/005-[partial]-casting.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0/2** acceptance (device QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I451-T01 | Native iOS + macOS AirPlay: periodic position events + `seek` channel | ✅ |
| 2 | I451-T02 | CastingService `position` / `seekIfCasting` + `CastHandoff.onPosition` | ✅ |
| 3 | I451-T03 | Desktop / mobile / Live Sports: mirror cast playhead; route scrub to AirPlay | ✅ |
| 4 | I451-T04 | Native play/pause + rate mirror; route Forja transport to AirPlay | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I451-A01 | Cast VOD to Apple TV; Forja seek bar advances; scrub in Forja seeks the TV | ⬜ |
| 2 | I451-A02 | Pause / play in Forja pauses / resumes the TV; TV remote pause updates Forja chrome | ⬜ |

---

## Problem

While AirPlay was active, the in-app seek bar stayed frozen (local player paused). Scrubbing in Forja did not move the TV. Desktop felt worse than phone because Mac chrome stays on screen and system Now Playing is less of a substitute.

## Root cause

AirPlay uses a separate muted `AVPlayer`. Events were only `active` / `inactive` / `error` — no live position, no seek. The seek bar followed paused media_kit.

## Fix

Native channels emit `position` ~2 Hz while external playback is active and accept `seek` / `play` / `pause`. Rate KVO mirrors TV-side pause. CastingService forwards ticks and play state to `CastHandoff`; players route scrub and transport through `seekIfCasting` / `setPlayingIfCasting`. Local position/playing listeners ignore updates while AirPlay is active.
