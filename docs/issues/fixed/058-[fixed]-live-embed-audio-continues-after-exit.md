# 058 — Live Matches embed audio continues after exit

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `features/live_matches` WebView embed player

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6/6** fix · **0/1** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I58-T01 | Store `InAppWebViewController`; stop HTML media + blank iframes + `about:blank` on exit | ✅ |
| 2 | I58-T02 | `PopScope` + back button call stop before `Navigator.pop` | ✅ |
| 3 | I58-T03 | Disable `allowsPictureInPictureMediaPlayback` on live embed settings | ✅ |
| 4 | I58-T04 | Chrome above WebView (not overlaid) so Back taps are not stolen by WKWebView | ✅ |
| 5 | I58-T05 | Stop/blank with timeouts; never block pop on hung WebView IPC; Escape handler | ✅ |
| 6 | I58-T06 | Do not `controller.dispose()` while `InAppWebView` still mounted | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I58-A01 | App: open Streamed/CDN/PPV embed, hear audio, Back/Escape — player closes and audio stops (manual) | ⬜ |

---

## Summary

Exiting a Live Matches WebView embed (Streamed / CDN / PPV fallback) left HTML5 / iframe audio playing — and on desktop the Back control often never ran exit at all.

### Root cause

1. Dispose only tore down Flutter chrome; platform WebView kept media alive.
2. Top-bar Back was painted **over** the WKWebView platform view, which steals mouse hits on macOS — taps never reached Flutter.
3. `_exitPlayer` awaited WebView JS/`about:blank` with no timeout; hung IPC left the route stuck open with audio still playing.
4. Disposing the controller while `InAppWebView` was still mounted could hang the platform view.

### Fix (shipped)

- Chrome (`Column` above WebView) so Back is outside the platform view
- Timed stop/blank; pop within ~700ms even if WebView IPC hangs
- Escape key → `_exitPlayer`
- PiP disabled; no early `controller.dispose()`

### Verify

1. Live Matches → open a Streamed (or CDN) stream until audio plays
2. Tap the player **Back** button (or Escape)
3. Player must close and audio must stop

## Related

- [046](../046-[open]-streamed-live-embed-white-screen.md) — iframe wrapper
- [049](../049-[open]-live-embed-ad-hijack-crash.md) — ad window host
- [053](../053-[workaround]-windows-live-embed-webview2-transparent.md) — Windows direct embed
- [059](059-[fixed]-vod-player-audio-continues-after-exit.md) — movie/TV player (same symptom)
- [Live Matches](../../features/live/live-matches.md)
