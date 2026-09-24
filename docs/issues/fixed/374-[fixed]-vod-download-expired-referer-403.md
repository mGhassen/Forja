# 374 — VOD Download reuses expired provider Referer (HTTP 403)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**RFC:** [RFC-117](../../rfc/117-[open]-vod-offline-downloads.md)  
**Related:** [365](../365-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** tasks · **2 / 2** acceptance |
| **Current slice** | Fixed — player re-extract + fail-fast 403 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I374-T01 | Check `expires=` / JWT on Referer (not only play URL) before enqueue | ✅ |
| 2 | I374-T02 | Player Download re-extracts pinned Forja provider before enqueue | ✅ |
| 3 | I374-T03 | `DownloadService` fails immediately on 401/403/404/410 (no reconnect spam) | ✅ |
| 4 | I374-T04 | Atomic download-task persist + changelog / feature tip | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I374-A01 | Mid-watch Download of a tokenized Forja stream enqueues a fresh URL (not the cold mid-session link) | ✅ |
| 2 | I374-A02 | Expired Referer / HTTP 403 shows a clear fail — no five reconnect attempts | ✅ |

---

## Problem

Player Download of **Vixsrc** (`engine:vixsrc`) used the in-player URL `vidsrc.buzz/_stream?id=…` with an embed Referer whose `expires=` was already past. Playback kept going on the open connection; the fresh HTTP GET for offline download returned **403**, and `DownloadService` retried five times.

## Root cause

1. Play URL has no `expires=` — only the **Referer** carries the short-lived token.
2. Phase-1 Download reused the mid-watch URL instead of re-extracting (unlike Resume Play).
3. 403 was treated as a reconnectable network error.

## Fix

- Guard downloads with Referer/Origin token expiry.
- Player Download re-extracts the pinned Forja plugin before enqueue.
- Fail fast on 401/403/404/410 with “Stream link expired…”.
