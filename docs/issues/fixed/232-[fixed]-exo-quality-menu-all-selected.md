# 232 — ExoPlayer Quality menu marks every variant selected

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed  
**Area:** `ForjaExoPlayerPlugin.kt` · ExoPlayer Quality menu  
**Reported:** 2026-09-07

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I232-T01 | When `videoAuto`, map `selected` from playing `videoFormat` match (not ABR `isTrackSelected`) | ✅ |
| 2 | I232-T02 | Locked quality still uses `isTrackSelected` / override | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I232-A01 | Manual: Exo Adaptive HLS → Quality shows one check on the playing height; lock another → only that row checked; Auto reappears | ⬜ |

---

## Summary

Opening **Quality** on ExoPlayer (Auto / ABR) showed a checkmark on every resolution row.

## Root cause

Media3 adaptive video selection marks **every** candidate in the adaptive group as `Tracks.Group.isTrackSelected(i) == true`. The bridge forwarded that flag unchanged, so the Flutter menu painted every row selected.

## Fix

In `trackList` for `TRACK_TYPE_VIDEO` while `videoAuto`: pick the supported track that best matches `player.videoFormat` (height, then bitrate / width) and set `selected` only on that row. Manual lock still uses `isTrackSelected` after a `TrackSelectionOverride`.
