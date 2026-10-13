# 424 — MediaKit: same subtitle cue painted twice

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Player · MediaKit · subtitles

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I424-T01 | Shared `subtitleTrackNeedsNativeRender` + awaitable `applyPlayerSubtitleRenderMode` (`sub-visibility` XOR Flutter; `secondary-sid=no`) | ✅ |
| 2 | I424-T02 | Overlay text via `formatPlayerSubtitleOverlayText` (dedupe primary/secondary twin lines); wire desktop/mobile/IPTV/Live Sports + file picker race | ✅ |
| 3 | I424-T03 | Changelog bullet | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I424-A01 | MediaKit VOD: SRT/VTT (in-stream or online) shows one cue line; ASS still uses libass only; Off clears | ⬜ |

---

## Summary

MediaKit keeps two paint paths: libass on the video frame (`sub-visibility`) and a Flutter overlay from `player.stream.subtitle` (`[primary, secondary]`). They must be exclusive for SRT/VTT vs ASS/PGS.

**Root cause:** `sub-visibility` was set fire-and-forget (and sometimes before `setSubtitleTrack` finished), so libass and the Flutter overlay could both show the same cue. Overlay also joined primary + secondary without deduping identical lines.

**Root fix:** await render-mode apply after track select; pin `secondary-sid=no` for the Flutter path; collapse duplicate overlay lines.

## Related

- [features/playback/subtitles.md](../../features/playback/subtitles.md)
- [230](../230-[open]-android-tv-exo-subtitles-invisible.md) — Exo Flutter cue paint (separate engine)
