# 396 — Saved stream drops in-stream subtitles

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** tasks · **0 / 1** acceptance |
| **Current slice** | Sidecar save is in the HLS downloader — not checked by playing a new save |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I396-T01 | HLS save writes each in-stream subtitle rendition next to the video | ✅ |
| 2 | I396-T02 | Play of that file lists those files in the subtitle menu as In-stream | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I396-A01 | A new HLS save’s subtitle menu shows the stream’s languages, and one of them plays with the video | ⬜ |

---

## Problem

Playing a saved file does not list the in-stream subtitles that the same stream shows online.

## Root cause

Those tracks are a subtitle playlist beside the video, not samples inside the video segments. The downloader saved the video variant only. Offline play has no playlist left to read.

## Fix

While saving HLS, download the subtitle rendition for the chosen variant and write a WebVTT file per language next to the video. Play attaches those files to the subtitle menu as In-stream. A subtitle fetch that fails does not fail the video. Files saved before this change do not grow a sidecar.
