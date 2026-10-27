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

Verified on AnimeKai desktop (`in-stream renditions=0` from the master — **no** HLS `TYPE=SUBTITLES`). Auto-pick attaches provider English via `sub-file`. mpv then exposes numeric demux twins labeled “English · In-stream”. Menu listed those ghosts. Demux `onTap` called `preparePlayerExternalSubtitleSwitch` (clears `sub-file`) + `onExternalUrlChanged(null)` → working AnimeKai cues die, and another demux ghost appears. HLS VTT materialize never ran on this path.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I495-T01 | Materialize HLS in-stream → local VTT/SRT before MediaKit attach; reuse cache | ✅ |
| 2 | I495-T02 | Always hide demux twins of HLS playlist rows; demux tap routes to HLS pick | ✅ |
| 3 | I495-T03 | Desktop/mobile auto HLS pick uses the same attach helper | ✅ |
| 4 | I495-T04 | Unit: twin hide always / matching-track helper | ✅ |
| 5 | I495-T05 | Hide demux twins of any attached sideload + selected online language; demux tap must not clear `sub-file`; re-select sideload twin | ✅ |
| 6 | I495-T06 | Unit: findAttachedSideloadTwin | ✅ |

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
- [507](../507-[open]-exo-hls-instream-subtitles-no-cues.md) — Exo same materialize gap
