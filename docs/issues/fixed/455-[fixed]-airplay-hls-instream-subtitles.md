# 455 — AirPlay drops HLS in-stream subtitles

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**RFC:** [RFC-005](../../rfc/005-[partial]-casting.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0/1** acceptance (device QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I455-T01 | `castSubtitleFor` merges HLS subtitle media playlists via `hlsSubtitleRenditionToVtt` | ✅ |
| 2 | I455-T02 | Desktop / mobile / Live Sports pass stream + playback headers into cast subtitle fetch | ✅ |
| 3 | I455-T03 | Unit test: m3u8 in-stream URI → `CastSubtitleKind.external` WebVTT | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I455-A01 | Cast an HLS VOD with an in-stream English subtitle selected; Apple TV shows those cues | ⬜ |

---

## Problem

AirPlay played the video but not the in-stream subtitle Forja was showing. The player said the subtitle could not play on AirPlay.

## Root cause

Forja strips HLS `TYPE=SUBTITLES` for local play and re-attaches the chosen rendition as `SubtitleTrack.uri` pointing at a subtitle `.m3u8`. Cast treated that as external and only accepted raw SRT/VTT bodies (`-->` cue timings). An HLS subtitle playlist has none, so cast returned `unsupported`.

## Fix

Before AirPlay, merge the active HLS subtitle playlist into one WebVTT file (same path as offline download sidecars), apply subtitle delay, and send `CastSubtitleKind.external` through the existing LAN subtitle relay. ASS / image / non-HLS still unsupported.
