# 495 — MediaKit: HLS in-stream shows no cues and duplicates menu rows

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Desktop / phone MediaKit player · subtitle menu · HLS in-stream  
**Reported:** 2026-10-26 (desktop: AnimeKai + In-stream English rows)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **1 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. Pick an In-stream subtitle → cues stay blank until an online/addon subtitle (AnimeKai, Levrx, …) is chosen first.
2. Each In-stream pick (or reopen) adds another identical “English · In-stream” row.

## Root cause

HLS playlist rows were attached with `SubtitleTrack.uri` pointing at a subtitle `.m3u8`. mpv does not paint those cues as `sub-file` (AirPlay/offline already merge to WebVTT). Demux twins of the same language stayed listed beside the playlist row, and each URI attach grew mpv’s track list — [474](474-[fixed]-mediakit-hls-instream-subtitle-menu-twins.md) only partially covered reuse/dedupe and left acceptance unverified.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I495-T01 | Materialize HLS in-stream → local VTT/SRT before MediaKit attach; reuse cache | ✅ |
| 2 | I495-T02 | Always hide demux twins of HLS playlist rows; demux tap routes to HLS pick | ✅ |
| 3 | I495-T03 | Desktop/mobile auto HLS pick uses the same attach helper | ✅ |
| 4 | I495-T04 | Unit: twin hide always / matching-track helper | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I495-A01 | Desktop: pick HLS In-stream English → cues paint without picking AnimeKai first | ⬜ |
| 2 | I495-A02 | Same pick again / reopen menu → still one In-stream English row, checked | ⬜ |
| 3 | I495-A03 | Unit: twin / matching helpers | ✅ |

## Links

- [474](474-[fixed]-mediakit-hls-instream-subtitle-menu-twins.md) — prior menu-twin work (incomplete)
- [424](424-[fixed]-mediakit-double-subtitle-paint.md) — cue paint twin, not menu rows
- [455](455-[fixed]-airplay-hls-instream-subtitles.md) — AirPlay merge-to-VTT precedent
