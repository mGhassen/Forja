# 396 — Saved stream drops in-stream subtitles

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** tasks · **0 / 2** acceptance |
| **Current slice** | Provider subtitle rows now saved for HTTP and HLS files — not checked by playing a new save |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I396-T01 | HLS save writes each in-stream subtitle rendition next to the video | ✅ |
| 2 | I396-T02 | Play of that file lists those files in the subtitle menu as In-stream | ✅ |
| 3 | I396-T03 | The task record keeps the subtitle rows the stream row carried | ✅ |
| 4 | I396-T04 | HTTP and HLS saves fetch those rows next to the video, labelled by their source | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I396-A01 | A new HLS save’s subtitle menu shows the stream’s languages, and one of them plays with the video | ⬜ |
| 2 | I396-A02 | A new Castle save lists Castle’s subtitle languages offline, and one of them plays with the video | ⬜ |

---

## Problem

Playing a saved file does not list the in-stream subtitles that the same stream shows online.

## Root cause

Those tracks are a subtitle playlist beside the video, not samples inside the video segments. The downloader saved the video variant only. Offline play has no playlist left to read.

Second route, found on real saves (Lanterns via Castle, 2026-10-06): most packs attach subtitles as links on the stream row, not in the HLS master. Castle’s download URL is a single variant playlist, so the master-playlist sidecar found nothing. The download prep dropped the stream row’s subtitle list, and the task record had no field for it.

## Fix

While saving HLS, download the subtitle rendition for the chosen variant and write a WebVTT file per language next to the video. Play attaches those files to the subtitle menu as In-stream. A subtitle fetch that fails does not fail the video. Files saved before this change do not grow a sidecar.

The stream row’s subtitle list is stored on the task. When the video is complete, HTTP and HLS saves fetch each link (or write inline text) into the same sidecar folder and index, tagged with the source name. Offline play lists them beside any in-stream tracks. Anime sources whose packs never surface subtitles (Megaplay, Anikoto) have nothing to save; that is a pack gap outside this issue.
