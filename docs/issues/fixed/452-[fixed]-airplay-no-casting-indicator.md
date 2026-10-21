# 452 — AirPlay: no casting indicator while active

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
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
| 1 | I452-T01 | Sticky "Playing on AirPlay" notice while `airPlayActive` (status overlay + Live Sports) | ✅ |
| 2 | I452-T02 | Cast button uses connected icon + active chrome while casting | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I452-A01 | Cast VOD on Mac; "Playing on AirPlay" stays visible and cast icon stays active until cast ends | ⬜ |

---

## Problem

While AirPlay was playing, Forja only flashed a 3s toast (or nothing on Live Sports). The cast icon stayed idle. Users could not tell the stream was on the TV.

## Fix

`PlayerStatusOverlay` (and `PlayerAirPlayCastingNotice` for Live Sports) mirror `CastingService.airPlayActive` with a sticky top notice. Cast control switches to connected/active while casting.
