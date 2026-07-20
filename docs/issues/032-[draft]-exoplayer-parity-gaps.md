# 032 — ExoPlayer built-in parity gaps vs media_kit

**Status:** draft  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja/lib/shared/player/`, Android Media3

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 10** verification |
| **Current slice** | Floating menus + Media3 track/rate/fit APIs shipped; ASS / torrent localhost / seek preview / PiP / `audioUrl` still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I32-A01 | ASS/SSA subtitles on ExoPlayer path or documented media_kit-only | ⬜ |
| 2 | I32-A02 | Local torrent localhost stream on ExoPlayer (issue 024 parity) | ⬜ |
| 3 | I32-A03 | Seek bar preview on ExoPlayer path | ⬜ |
| 4 | I32-A04 | HLS manual quality picker on ExoPlayer | ✅ |
| 5 | I32-A05 | PiP on ExoPlayer Android path | ⬜ |
| 6 | I32-A06 | Separate `audioUrl` track on ExoPlayer | ⬜ |
| 7 | I32-A07 | Audio track picker on ExoPlayer (Media3 tracks) | ✅ |
| 8 | I32-A08 | Subtitle track picker on ExoPlayer (Off + text tracks) | ✅ |
| 9 | I32-A09 | Lean Settings on ExoPlayer (playback speed + fit) | ✅ |
| 10 | I32-A10 | TMDB + hub Episodes panels on ExoPlayer | ✅ |

---

## Summary

[RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md) ships ExoPlayer as Android default built-in engine.

**Shipped on Exo:** floating `PlayerPopupPanel` menus for Source, Episodes (hub + TMDB), Audio, Subtitles, Quality, lean Settings (speed + fit), and Player (engine / external). Native bridge exposes `getTracks` / `selectTrack` / `setRate` / `setResizeMode`. **PiP** and **Cast** chrome buttons are hidden on Exo (not stubbed toasts).

**Still media_kit-only (or open):** ASS/SSA styling, torrent localhost, seek preview, PiP, separate `audioUrl`. Users can switch **Settings → Built-in engine → MediaKit** when needed.
