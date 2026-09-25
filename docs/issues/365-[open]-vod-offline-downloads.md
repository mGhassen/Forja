# 365 — VOD offline Downloads (dual entry)

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**RFC:** [RFC-117](../rfc/117-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **24 / 27** tasks (2 deferred) · **20 / 20** acceptance |
| **Current slice** | Phase 1 + integrity follow-ups ([377](377-[open]-vod-offline-play-corrupt-file-stream-hop.md)) |

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
| 13 | I365-T13 | Sources card inline confirm + size probe (portal delete/share style) before enqueue | ✅ |
| 14 | I365-T14 | Player Download re-extract + Referer expiry / fail-fast 403 ([374](fixed/374-[fixed]-vod-download-expired-referer-403.md)) | ✅ |
| 15 | I365-T15 | Same-title dedup toast + init race / Settings queue visibility ([376](fixed/376-[fixed]-vod-download-dedup-toast-empty-settings.md)) | ✅ |
| 16 | I365-T16 | Sources card download progress + offline stripes; Filters Offline / Online | ✅ |
| 17 | I365-T17 | Corrupt Range resume + offline play stream-hop ([377](377-[open]-vod-offline-play-corrupt-file-stream-hop.md)) | 🔄 |
| 18 | I365-T18 | Sources active-download rail: Pause / Resume + delete (X), not Download again | ✅ |
| 19 | I365-T19 | Active speed/ETA flash every second ([379](fixed/379-[fixed]-vod-download-speed-eta-flash.md)) | ✅ |
| 20 | I365-T20 | Android TV: no Downloads UI (Settings, details, Sources, player) and no queue boot | ✅ |
| 21 | I365-T21 | Sources Offline row tap plays the on-disk file; hover Delete removes it | ✅ |
| 22 | I365-T22 | Offline Sources hover: Play online opens the cloud stream beside Delete | ✅ |
| 23 | I365-T23 | Sources shows saved / in-progress downloads before provider search finishes | ✅ |
| 24 | I365-T24 | Details hero has no Download button; enqueue stays on Sources and the player | ✅ |
| 25 | I365-T25 | Player Sources button shows an offline icon while the saved file is playing | ✅ |
| 26 | I365-T26 | Sources row saved from the player (`engine:<id>` chip) plays the file on tap; cloud stays online | ✅ |
| 27 | I365-T27 | Player chrome has no Download button; enqueue stays on Sources | ✅ |

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
| 9 | I365-A09 | Sources Download: card shows probed size (or estimate) + Yes/No before enqueue | ✅ |
| 10 | I365-A10 | Mid-watch Forja Download uses a fresh extract — expired Referer does not 403-loop | ✅ |
| 11 | I365-A11 | Downloading / offline Sources rows show striped chrome; Filters Offline / Online | ✅ |
| 12 | I365-A12 | Active Sources download row hover shows Pause/Resume + delete — not Download | ✅ |
| 13 | I365-A13 | Android TV has no Downloads entry (Settings, details, Sources, player) | ✅ |
| 14 | I365-A14 | Sources Offline row tap plays the saved file; hover Delete removes it | ✅ |
| 15 | I365-A15 | Offline Sources hover Play online opens the remote stream | ✅ |
| 16 | I365-A16 | Sources lists saved / in-progress downloads before provider search returns | ✅ |
| 17 | I365-A17 | Details hero has no Download button | ✅ |
| 18 | I365-A18 | Player Sources button shows an offline icon while the saved file is playing; Play online drops it | ✅ |
| 19 | I365-A19 | A source saved from the player still plays the file when its live URL changed; cloud plays online | ✅ |
| 20 | I365-A20 | Player chrome has no Download button | ✅ |

---

## Problem

Users cannot cache movies/episodes for offline watching. Multiple stream sources exist (Forja providers, Nuvio, Stremio, torrents) but there is no host Downloads library or dual-entry enqueue.

## Goal

Phase 1: Dart HTTP/HLS Downloads engine, dual entry, Settings → Downloads, offline play.
