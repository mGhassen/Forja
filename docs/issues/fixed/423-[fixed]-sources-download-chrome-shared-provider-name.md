# 423 — Sources paints every quality as downloading when one shares a provider name

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Related:** [365](../365-[open]-vod-offline-downloads.md) · [376](376-[fixed]-vod-download-dedup-toast-empty-settings.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** tasks · **2 / 2** acceptance |
| **Current slice** | Fixed — bind chrome by task id / play URL |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I423-T01 | Stop name/plugin fallback in `findTaskForStream` and cover checks | ✅ |
| 2 | I423-T02 | Ownership = task id, or URL + matching label (shared CDN stays sameFile) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I423-A01 | Downloading one quality (e.g. 1080p) does not stripe sibling qualities from the same provider | ✅ |
| 2 | I423-A02 | Another provider on the same CDN URL still gets sameFile chrome, not stripes | ✅ |

---

## Problem

Downloading one DahmerMovies 1080p row painted every DahmerMovies quality (4K + both 1080p) with the same progress and speed.

## Root cause

Sources matched download tasks by provider label (`_addonName` / `name`). Multi-quality rows share that label, so every sibling owned the same task.

## Fix

- Attach a task to a row only by `_downloadTaskId` or exact play URL.
- Ownership stripes require task id, or URL plus a matching source label (so a shared CDN URL on another provider stays `sameFile`).
- Name/plugin alone no longer covers a provider row — when the CDN URL rotated, the pinned offline row stays visible instead.
