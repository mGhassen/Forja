# 397 — A second source for the same episode is blocked as already saved

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** `apps/forja/lib/shared/downloads/`  
**RFC:** [RFC-117](../../rfc/117-[open]-vod-offline-downloads.md)  
**Related:** [376](376-[fixed]-vod-download-dedup-toast-empty-settings.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** tasks · **2 / 2** acceptance |
| **Current slice** | Fixed — one file per stream, listed per episode |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I397-T01 | Dedup a download by stream URL, not by episode slot | ✅ |
| 2 | I397-T02 | Second source gets its own file name; Downloads lists it under that episode | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I397-A01 | Download on a different source for an episode that already has a file starts a new save | ✅ |
| 2 | I397-A02 | The same stream still says already saved / already downloading and does not start again | ✅ |

---

## Problem

Sources blocked a second download for an episode that already had one file and toasted “Already saved offline”, even when the row was a different source.

## Root cause

`startDownload` returned the existing task for that `mediaId` + season + episode and ignored the URL. Both saves also targeted the same `Title_S01E01.mp4` path.

## Fix

Match an existing task on the stream URL. A different URL enqueues a new task whose file name includes the source. The Downloads panel already lists each finished file with its provider and stream.
