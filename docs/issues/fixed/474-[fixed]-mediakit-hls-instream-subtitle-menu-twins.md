# 474 — MediaKit: selecting HLS in-stream subtitle duplicates the menu row

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Desktop / phone MediaKit player · subtitle menu · HLS in-stream  
**Reported:** 2026-10-23 (desktop play-trace: VixSrc HLS resume)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Pick an in-stream (HLS playlist) subtitle, reopen the Subtitles menu → another "In-stream" row appears. Each pick adds one more row.

## Root cause

HLS menu pick called `setPlayerExternalSubtitle(SubtitleTrack.uri)` every time. mpv appends a track (and often a demux twin). The menu listed mux/demux rows **and** the unchanged playlist `_hls` rows, both labeled "In-stream". Twin filtering in `menuEmbeddedSubtitleTracks` only ran when `selectedExternalSubUrl != null`, which HLS pick clears. Tracks-listener length growth also cleared `_embeddedSubtitleAutoApplied` after a user pick, so auto could URI-attach again.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I474-T01 | Reuse attached HLS track / no-op when already selected; do not append URI again | ✅ |
| 2 | I474-T02 | Menu always hides demux twins of active URI/HLS playlist rows | ✅ |
| 3 | I474-T03 | User menu pick latches `_userPickedExternalSubtitle` so track growth does not re-arm auto URI attach | ✅ |
| 4 | I474-T04 | Unit tests for select match, find-attached, twin hide | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I474-A01 | Desktop: pick HLS in-stream English → reopen menu → still one In-stream English row, checked | ⬜ |
| 2 | I474-A02 | Desktop: pick the same row again → track count / menu count unchanged | ⬜ |
| 3 | I474-A03 | Unit: select / findAttached / twin helpers | ✅ |

---

## Links

- [458](458-[fixed]-exo-online-subtitle-pick-no-op-and-menu-twins.md) — Exo menu twins (same product bug, different engine)
- [424](424-[fixed]-mediakit-double-subtitle-paint.md) — cue paint twin, not menu rows
- [495](495-[fixed]-mediakit-hls-instream-no-cues-menu-twins.md) — follow-up: no cues on raw `.m3u8` attach + remaining twins
