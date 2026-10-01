# 376 — VOD Download toast says downloading but Settings queue empty / wrong source

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**RFC:** [RFC-117](../../rfc/117-[open]-vod-offline-downloads.md)  
**Related:** [365](../365-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** tasks · **2 / 2** acceptance |
| **Current slice** | Fixed — honest dedup toast + init race / orphan recovery |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I376-T01 | Dedup toast: “Already downloading / saved” instead of fake “Downloading…” | ✅ |
| 2 | I376-T02 | Serialize `DownloadService.initialize` so concurrent load cannot wipe enqueue | ✅ |
| 3 | I376-T03 | Re-attach orphaned progress updates; Settings reloads disk if memory empty | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I376-A01 | Second Sources Download for same title while Active shows “Already downloading…” + View | ✅ |
| 2 | I376-A02 | Settings → Downloads shows the Active row after enqueue (no empty queue while transfer runs) | ✅ |

---

## Problem

User confirmed Download on KissKh / Vixsrc, saw “Downloading…”, opened Settings, and saw no Active row (or expected those sources). Disk already had one offline slot for the title from another source (e.g. HdHub).

## Root cause

1. Phase 1 allows **one** offline task per `mediaId` (+ season/episode). `startDownload` returns the existing Active/Completed task, but enqueue always toasted **Downloading…**.
2. Bootstrap `initialize()` and first enqueue could both call `_loadPersistedTasks` without a lock — a late empty load could wipe the in-memory queue while HTTP still ran (`_updateTask` no-op when id missing).

## Fix

- Honest toast when the same slot is already Active/Completed.
- Single-flight init Completer; orphan progress re-inserts the task; Settings calls `ensureQueueVisible()`.
