# 507 — ExoPlayer: HLS In-stream subtitles show no cues

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android · ExoPlayer · subtitles · HLS  
**Reported:** 2026-10-28 (Android TV Exo; AnimeKai stream — In-stream row; provider AnimeKai VTT works)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On **ExoPlayer** (Android TV / phone), picking a Subtitles menu row labeled **In-stream** selects the row but **no cues paint**. Provider sideloads (e.g. AnimeKai VTT) on the same stream work.

## Root cause

Exo treated HLS `TYPE=SUBTITLES` playlist URIs like a plain SRT/VTT download (`_prepareSubtitleSideload` → GET → `isPlausibleSubtitleBytes`). A subtitle media playlist starts with `#EXTM3U` and is rejected. MediaKit already merges those playlists to a local VTT via `materializeHlsInStreamSubtitleFile` ([495](fixed/495-[fixed]-mediakit-hls-instream-no-cues-menu-twins.md)).

Auto-pick also short-circuited: `_hlsPlaylistCoversPreferred` returned true when the master listed the language, then **returned without attaching** — waiting for Media3 text tracks that never became a usable sideload.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I507-T01 | Exo prepare: In-stream / `.m3u8` / local proxy → `materializeHlsInStreamSubtitleFile` before Media3 sideload | ✅ |
| 2 | I507-T02 | Exo auto-pick: attach preferred HLS in-stream (materialize + setSubtitles) instead of wait-only gate; unit for materialize gate | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I507-A01 | Android TV Exo: pick In-stream English on an HLS master with `TYPE=SUBTITLES` → cues visible; Off clears | ⬜ |
| 2 | I507-A02 | Unit: `exoSideloadNeedsHlsMaterialize` In-stream / m3u8 / proxy / provider VTT | ✅ |

## Links

- [230](230-[open]-android-tv-exo-subtitles-invisible.md) — Flutter cue paint (separate; acceptance still open)
- [495](fixed/495-[fixed]-mediakit-hls-instream-no-cues-menu-twins.md) — MediaKit materialize precedent
- [458](fixed/458-[fixed]-exo-online-subtitle-pick-no-op-and-menu-twins.md) — Exo online pick / twins
