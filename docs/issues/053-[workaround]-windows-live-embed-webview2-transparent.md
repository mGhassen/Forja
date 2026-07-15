# Issue 053 — Windows Live Matches embed: white transparent / blank after macOS rewrite

**Status:** workaround  
**Priority:** P1  
**Severity:** High  
**Area:** `features/live_matches/live_matches_widgets.dart` · `shared/webview/forja_webview_settings.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I53-T01 | Windows: force `transparentBackground: true` in `forjaWebViewSettings` to skip inverted WebView2 DefaultBackgroundColor (alpha 0) | ✅ |
| 2 | I53-T02 | Windows Live Matches: restore direct `initialUrlRequest` embed (no iframe wrapper / multi-window); keep macOS iframe + off-screen `window.open` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I53-A01 | Windows: open a live Streamed/PPV/CDN embed — player shows opaque surface + video (not white transparent); Escape still pops | ⬜ |

---

## Summary

On Windows, opening a Live Matches stream pushed `_LiveMatchesEmbedPlayerScreen`. After the Jul 14–15 macOS embed rewrite (iframe wrapper + `supportMultipleWindows`, issues [046](046-[open]-streamed-live-embed-white-screen.md) / [049](049-[open]-live-embed-ad-hijack-crash.md)), Windows showed a **white transparent** surface; Escape still worked. Streams had worked on the prior direct `initialUrlRequest` path.

**Symptom:** White / see-through player after launching a working stream; Escape backs out.

**Root (two layers):**

1. **Regression:** macOS iframe + multi-window WebView path does not play reliably on WebView2 — restore Windows direct embed load (`I53-T02`).
2. **Upstream (still open):** `flutter_inappwebview_windows` 0.6.x create path inverts `transparentBackground`: `false` → alpha `0` (`in_app_webview.cpp` ~210). App-side force `true` (`I53-T01`). Upstream: [inappwebview#2735](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2735).

**Workaround (shipped):** Windows uses direct embed URL + opaque WebView2 settings; other platforms keep iframe wrapper + off-screen ad window. Not a root fix of the plugin color bug — remove `I53-T01` when upstream ships a corrected create-time color.
