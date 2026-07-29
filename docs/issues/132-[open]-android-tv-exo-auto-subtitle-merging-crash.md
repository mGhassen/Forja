# 132 — Android TV ExoPlayer: auto subtitle select crashes / pops player

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · ExoPlayer · subtitles · MergingMediaPeriod

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I132-T01 | Defer preferred / external subtitle select until Media3 STATE_READY; clear ready on open + setSubtitles soft-reload | ✅ |
| 2 | I132-T02 | Lock `_preferredSubtitleApplied` before `selectTrack` so concurrent `tracksChanged` cannot re-enter | ✅ |
| 3 | I132-T03 | Stop double `emitTracks` from Kotlin `selectTrack` (rely on `onTracksChanged`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I132-A01 | Android TV Anime/VOD with preferred English + sideloaded or embedded text tracks: play stays up; log shows one `auto subtitle → …` (not a spam loop); no `ProgressiveMediaPeriod.startLoading` IllegalStateException | ⬜ |

---

## Summary

On **Android TV**, opening a VOD (e.g. Anime continue watching) with ExoPlayer + preferred subtitles could die within a second: Media3 `ExoPlaybackException: Unexpected runtime error` → `IllegalStateException` in `ProgressiveMediaPeriod.startLoading` under `MergingMediaPeriod` → Dart `_failCurrentSource` → `onAllSourcesExhausted` pops the player back to the hub.

**Root causes:**

1. **`tracksChanged` → `_maybeApplyPreferredSubtitle` → `selectTrack` loop** — `_preferredSubtitleApplied` only short-circuited the English-*fallback* path (`preferredMatch == null`). When preferred was English, every tracks event re-selected the track. Kotlin also `emitTracks()` after `selectTrack`, doubling events with `onTracksChanged`.
2. **Select / soft-reload before READY** — MediaItem subtitle configs use MergingMediaSource. Changing text track selection (or `setSubtitles` soft-reload) while periods are still loading races `ProgressiveMediaPeriod.startLoading`.

**Root fix:** gate auto-apply on `_exoReady`; lock `_preferredSubtitleApplied` before `selectTrack`; clear ready on open / sideload soft-reload; drop redundant Kotlin `emitTracks` from `selectTrack`.

## Related

- [032](032-[draft]-exoplayer-parity-gaps.md) — Exo subtitle picker parity
- [features/playback/subtitles.md](../features/playback/subtitles.md)
