# 391 — Downloads hub stays empty after a save

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)  
**Related:** [382](382-[open]-downloads-hub.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** tasks · **0 / 1** acceptance |
| **Current slice** | Hub reload is in code — not checked on a device |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I391-T01 | `DownloadService.libraryRevision` bumps when a save completes or a finished title leaves that set | ✅ |
| 2 | I391-T02 | Downloads hub (offline panel) reloads immediately if open, or on next open if hidden | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I391-A01 | A finished save shows on the Downloads tab without leaving and coming back, and without a manual refresh | ⬜ |

---

## Problem

A finished download did not show on the Downloads tab. The hub paints once and keeps that grid. Opening the tab again does not fetch.

## Root cause

Keep-alive hubs skip a catalog fetch when the tab is shown again if the last envelope succeeded. An empty Downloads grid stays empty after a save finishes.

## Fix

A status change into or out of completed bumps `DownloadService.libraryRevision`. The hub that owns the offline panel reloads that feed (force, so the short feed cache is skipped). A hidden hub reloads the next time it is opened.
