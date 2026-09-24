# 379 — Downloads Active speed / ETA flash every second

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**RFC:** [RFC-117](../../rfc/117-[open]-vod-offline-downloads.md)  
**Related:** [365](../365-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** tasks · **2 / 2** acceptance |
| **Current slice** | Fixed — EMA speed hold + throttled task JSON persist |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I379-T01 | `DownloadSpeedSampler` EMA + hold last rate between 1s windows | ✅ |
| 2 | I379-T02 | HTTP + HLS progress use sampler; HLS no longer resets to initial 0 speed | ✅ |
| 3 | I379-T03 | Throttle `forja_download_tasks.json` writes on byte progress (flush on status change) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I379-A01 | Active row speed stays continuous (no `0 KB/s` / `…` flash every ~1s while bytes rise) | ✅ |
| 2 | I379-A02 | ETA stays visible with the smoothed rate while downloading | ✅ |

---

## Problem

Settings → Downloads Active showed speed and ETA jumping every second (often to `0 KB/s`), as if the transfer paused — while received bytes kept climbing.

## Root cause

1. Speed was a raw last-1-second sample with no smoothing.
2. HLS progress used the **original** `task.speedBytesPerSec` (always `0`) between sample windows, so every mid-window segment pushed `0 KB/s` and cleared ETA.
3. Every progress tick rewrote the full tasks JSON on disk (same volume as the `.part` file), adding bursty stalls that made the next 1s sample look empty.

## Fix

- Shared `DownloadSpeedSampler` (EMA + hold).
- HTTP and HLS report the sampler rate; HLS meta writes throttled.
- Progress-only `_updateTask` schedules persist (~5s); status changes flush immediately.
