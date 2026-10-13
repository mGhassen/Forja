# 422 — AirPlay offline file: Cannot Open

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
| 1 | I422-T01 | Detect `file://` AirPlay start and serve the saved file over LAN HTTP with Range | ✅ |
| 2 | I422-T02 | Wire iOS + macOS AirPlay channels to open the LAN URL; clear error when Wi-Fi/LAN is missing | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I422-A01 | Cast a finished offline MP4 to Apple TV on the same Wi-Fi; TV plays and resume returns to Forja | ⬜ |

---

## Problem

Casting a finished offline download to AirPlay logged `AirPlay error: Cannot Open` and failed.

## Root cause

AirPlay hands the play URL to `AVPlayer` with external playback. Offline play uses a local `file://` path. The Apple TV cannot read files on the phone, so the item fails.

## Fix

`ForjaAirPlayLocalFileRelay` binds a tokenized LAN HTTP server for the saved file (byte-range for seek). The AirPlay channel rewrites `file://` to that HTTP URL before open. Needs Wi-Fi so the TV can reach the phone. Formats AVPlayer cannot decode (e.g. some MKV) still fail after serve — same as online AVPlayer limits.
