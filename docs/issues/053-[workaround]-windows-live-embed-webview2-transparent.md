# Issue 053 — Windows Live Matches embed: white transparent / blank after macOS rewrite

**Status:** workaround  
**Priority:** P1  
**Severity:** High  
**Area:** `features/live_matches/live_matches_widgets.dart` · `shared/webview/forja_webview_settings.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I53-T01 | Windows: force `transparentBackground: true` in `forjaWebViewSettings` to skip inverted WebView2 DefaultBackgroundColor (alpha 0) | ✅ |
| 2 | I53-T02 | Windows Live Matches: restore direct `initialUrlRequest` embed (no iframe wrapper / multi-window); keep macOS iframe + off-screen `window.open` | ✅ |
| 3 | I53-T03 | Windows Live Matches: drop direct embed; use same iframe wrapper + off-screen `window.open` as macOS (keep `I53-T01` opaque WebView2) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I53-A01 | Windows: open a live Streamed/PPV/CDN embed — player shows opaque surface + video (not white transparent); Escape still pops | ⬜ |

---

## Summary

On Windows, opening a Live Matches stream pushed `_LiveMatchesEmbedPlayerScreen`. After the Jul 14–15 macOS embed rewrite (iframe wrapper + `supportMultipleWindows`, issues [046](046-[open]-streamed-live-embed-white-screen.md) / [049](049-[open]-live-embed-ad-hijack-crash.md)), Windows showed a **white transparent** surface; Escape still worked. Streams had worked on the prior direct `initialUrlRequest` path.

**Symptom (original):** White / see-through player after launching a working stream; Escape backs out.

**Symptom (post-`I53-T02`):** Direct top-level embed on Windows often left a blank/black player (Streamed needs catalog `document.referrer` + successful off-screen `window.open` — same root as [046](046-[open]-streamed-live-embed-white-screen.md)).

**Root (two layers):**

1. **Upstream (still open):** `flutter_inappwebview_windows` 0.6.x create path inverts `transparentBackground`: `false` → alpha `0` (`in_app_webview.cpp` ~210). App-side force `true` (`I53-T01`). Upstream: [inappwebview#2735](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2735).
2. **Playback path:** Direct embed skips the iframe parent that Streamed expects. `I53-T02` restored direct load to dodge WebView2 white-screen; `I53-T03` puts Windows back on the shared iframe + off-screen ad-window path while keeping `I53-T01`.

**Workaround (current):** Opaque WebView2 settings (`I53-T01`) + shared iframe / `window.open` path (`I53-T03`). Not a root fix of the plugin color bug — remove `I53-T01` when upstream ships a corrected create-time color. `I53-T02` remains a historical ship row.
