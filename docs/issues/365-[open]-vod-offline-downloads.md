# 365 — VOD offline Downloads (dual entry)

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **11 / 11** tasks · **9 / 9** acceptance |
| **Current slice** | Phase 1 complete — Phase 2/3 deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I365-T01 | RFC-117 + this issue + index rows | ✅ |
| 2 | I365-T02 | `DownloadService` + HLS engine + path/storage helpers + persistence | ✅ |
| 3 | I365-T03 | Details / episode Download (auto-resolve, no player) | ✅ |
| 4 | I365-T04 | Sources download mode | ✅ |
| 5 | I365-T05 | In-player Download of current stream | ✅ |
| 6 | I365-T06 | Settings → Downloads page + storage + View toast deep link | ✅ |
| 7 | I365-T07 | Offline local-file playback | ✅ |
| 8 | I365-T08 | Feature guide + changelog when user-visible | ✅ |
| 9 | I365-T09 | Phase 2 — debrid / torrent Keep-offline | ⏭️ |
| 10 | I365-T10 | Phase 3 — OS background downloads | ⏭️ |
| 11 | I365-T11 | Sources row hover Download icon; details Download opens Sources (no auto-pick) | ✅ |
| 12 | I365-T12 | Reject DASH MPD / tiny manifest responses (no ~60KB “completed” junk) | ✅ |
| 13 | I365-T13 | Probe size + confirm sheet before enqueue (HTTP Content-Length / HLS estimate) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I365-A01 | Enqueue from details without opening player | ✅ |
| 2 | I365-A02 | Enqueue from Sources and from player | ✅ |
| 3 | I365-A03 | Settings → Downloads shows queue progress and completed items | ✅ |
| 4 | I365-A04 | Storage used + free shown; delete frees disk | ✅ |
| 5 | I365-A05 | Play offline from Completed | ✅ |
| 6 | I365-A06 | App kill → tasks resume as paused (not stuck downloading) | ✅ |
| 7 | I365-A07 | Sources: hover reveals Download; row tap still plays | ✅ |
| 8 | I365-A08 | DASH / playlist / &lt;256KB responses fail instead of completing | ✅ |
| 9 | I365-A09 | Download confirms with probed size (or estimate) and free space before enqueue | ✅ |

---

## Problem

Users cannot cache movies/episodes for offline watching. Multiple stream sources exist (Forja providers, Nuvio, Stremio, torrents) but there is no host Downloads library or dual-entry enqueue.

## Goal

Phase 1: Dart HTTP/HLS Downloads engine, dual entry, Settings → Downloads, offline play.
