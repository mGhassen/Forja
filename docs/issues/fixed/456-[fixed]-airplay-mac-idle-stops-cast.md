# 456 — AirPlay: Mac idle stops the cast

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**RFC:** [RFC-005](../../rfc/005-[partial]-casting.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2/2** tasks · **0/1** acceptance (device QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I456-T01 | Hold `NoIdleSleep` IOPM assertion while macOS AirPlay is external | ✅ |
| 2 | I456-T02 | Hold `WakelockPlus` for the whole AirPlay session (re-enable after local pause) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I456-A01 | Cast VOD on Mac; leave Mac idle past display-sleep timer; TV keeps playing until cast ends | ⬜ |

---

## Problem

AirPlay pauses local media_kit. MediaKit then drops its display-sleep wakelock. The Mac idles/sleeps and the muted `AVPlayer` + LAN subtitle/file relays die, so the cast stops.

## Fix

macOS AirPlay channel holds `kIOPMAssertionTypeNoIdleSleep` while external playback is active (released on teardown). `CastingService` also holds `WakelockPlus` for the session and re-enables after the local pause lands so media_kit cannot clear it.
