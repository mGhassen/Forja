# 058 — Live Matches embed audio continues after exit

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `features/live_matches` WebView embed player

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** fix · **0/1** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I58-T01 | Store `InAppWebViewController`; stop HTML media + blank iframes + `about:blank` + dispose on exit | ✅ |
| 2 | I58-T02 | `PopScope` + back button call stop before `Navigator.pop` | ✅ |
| 3 | I58-T03 | Disable `allowsPictureInPictureMediaPlayback` on live embed settings | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I58-A01 | App: open Streamed/CDN/PPV embed, hear audio, Back/Escape — audio stops immediately (manual) | ⬜ |

---

## Summary

Exiting a Live Matches WebView embed (Streamed / CDN / PPV fallback) left HTML5 / iframe audio playing. Flutter only tore down chrome (timers, focus, fullscreen); the platform WebView kept media alive.

### Root cause

`_LiveMatchesEmbedPlayerScreen.dispose` did not pause `video`/`audio`, blank iframes, load `about:blank`, or dispose the `InAppWebViewController`. Forced unmuted autoplay plus `allowsPictureInPictureMediaPlayback: true` made leftover OS media sessions more likely.

Native IPTV/media_kit path (`IptvPtPlayerScreen`) already stops+disposes — this bug is WebView-embed only.

### Fix (shipped)

- `_stopEmbedMedia()` — JS pause/mute/clear + blank iframes, `stopLoading`, `about:blank`, `controller.dispose()`
- Back button + system back (`PopScope`) await stop before pop; `dispose` still calls stop as a safety net
- PiP media playback disabled on live embed settings

### Verify

1. Live Matches → open a Streamed (or CDN) stream until audio plays
2. Tap Back or press Escape
3. Audio must stop; no ghost sound while browsing the schedule

## Related

- [046](../046-[open]-streamed-live-embed-white-screen.md) — iframe wrapper
- [049](../049-[open]-live-embed-ad-hijack-crash.md) — ad window host
- [053](../053-[workaround]-windows-live-embed-webview2-transparent.md) — Windows direct embed
- [Live Matches](../../features/live/live-matches.md)
