# 377 — Offline play opens corrupt download then hops to “Checking sources”

**Status:** open  
**Priority:** P1  
**Severity:** High  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)  
**Related:** [365](365-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** tasks · **0 / 3** acceptance |
| **Current slice** | Integrity + offline fail UX landing |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I377-T01 | Reproduce: completed offline file unplayable + player shows Checking sources | ✅ |
| 2 | I377-T02 | HTTP Range resume: re-stat disk vs Content-Range; reject non-media finalize; Disposition extension | ✅ |
| 3 | I377-T03 | Offline play: no online provider hop; pinSource; pre-flight magic; honest failure copy | ✅ |
| 4 | I377-T04 | Manual: re-download HdHub/pixeldrain title; Play from Settings → Downloads plays locally | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I377-A01 | Corrupt/incomplete part never marks Completed | ⬜ |
| 2 | I377-A02 | Play on a bad completed file toasts / fails locally — no Checking sources / Failed to stream | ⬜ |
| 3 | I377-A03 | Fresh download of Matroska (Content-Disposition `.mkv`) plays offline | ⬜ |

---

## Problem

Playing **The Love Hypothesis** from Settings → Downloads opened the local `file://` path, but mpv reported **Failed to recognize file format**. The player then auto-fell back like an online stream (**Checking sources** / **Failed to stream**), which looks like buffering offline.

## Root cause

1. **Corrupt on-disk file** — local bytes were `zeros(3578) + remote[4151:]` (573 bytes short of server `Content-Length`). Remote is Matroska (`video/matroska`, Disposition `.mkv`); local was saved as `.mp4` with the EBML header missing. Classic Range resume / overlapping writer: in-memory offset ahead of EOF, append at short EOF while Range skipped the gap.
2. **Offline open failure hops online** — primary open retry path called `_autoFallbackToNextProvider` when `_providerPinned` was false, even with `streamsPrevalidated: true` and a local file. Status roulette still said **Failed to stream**.

## Fix

- Validate `Content-Range` start vs on-disk length before append; realign or restart.
- Finalize requires known media magic + size within 256B of expected total.
- Prefer `.mkv` / etc. from Content-Disposition / Content-Type.
- Serialise overlapping HTTP executors per task.
- Offline Play: `pinSource`, magic pre-check, no provider hop; failure copy uses the real message.

## Symptom vs root

| Layer | Status |
|-------|--------|
| Symptom (misleading Checking sources / Failed to stream on offline) | Fixed in player + Settings Play |
| Root (corrupt Range resume completing as playable) | Hardened in DownloadService — confirm with I377-T04 |
