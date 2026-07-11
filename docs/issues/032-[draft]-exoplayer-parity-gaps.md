# 032 — ExoPlayer built-in parity gaps vs media_kit

**Status:** draft  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja/lib/shared/player/`, Android Media3

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 6** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I32-A01 | ASS/SSA subtitles on ExoPlayer path or documented media_kit-only | ⬜ |
| 2 | I32-A02 | Local torrent localhost stream on ExoPlayer (issue 024 parity) | ⬜ |
| 3 | I32-A03 | Seek bar preview on ExoPlayer path | ⬜ |
| 4 | I32-A04 | HLS manual quality picker on ExoPlayer | ⬜ |
| 5 | I32-A05 | PiP on ExoPlayer Android path | ⬜ |
| 6 | I32-A06 | Separate `audioUrl` track on ExoPlayer | ⬜ |

---

## Summary

[RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md) ships ExoPlayer as Android default built-in engine. These features remain **media_kit-only** until explicitly ported. Users switch **Settings → Built-in engine → MediaKit** when needed.
