# Issue 049 — Live Matches embed: ad main-frame hijack crashes app

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `features/live_matches/` embed WebView (`live_matches_widgets.dart`)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I49-T01 | Do **not** HTML-sandbox the embed iframe (hosts reject it); cancel main-frame hijacks in `shouldOverrideUrlLoading` | ✅ |
| 2 | I49-T02 | Freeze WebView `initialData`/settings in `initState`; stop `setState` on post-ready `onLoadStart` | ✅ |
| 3 | I49-T03 | Surface ad `window.open` via `onCreateWindow` in a single movable bottom-right popup (drag + close); fix `ForjaInAppWebView` not forwarding GlobalKey to child | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I49-A01 | macOS: open a live Streamed/PPV match, leave playing ≥30s — app stays up (no `Lost connection` / process death); player still shows video | ⬜ |

---

## Summary

Opening a live match embed flooded the log with `[LiveMatches] blocked main-frame nav:` to ad click hosts (`gotrackier.com`, `gamerhit.co`, `linkics.com`, `roadster24.com`, `rovno.xyz`, …), interleaved with repeated `InAppWebView - dealloc`, then **Lost connection to device** / process exit.

**Symptom:** App process dies while watching a live embed.

**Root:** Third-party embed ads navigate / popup the **host WebView main frame**. Canceling those navigations under rebuild churn (`onLoadStart` → `setState`) correlated with native WKWebView teardown and a hard crash. Distinct from [046](046-[open]-streamed-live-embed-white-screen.md) (white screen / spinner), which remains the subframe-allow + iframe-wrapper track.

**Fix (shipped in code):** HTML `sandbox` on the embed iframe is **rejected** by the player (“SANDBOX IFRAME NOT ALLOWED”) — do not use it. Main-frame ad hijacks are cancelled in `shouldOverrideUrlLoading`. Ad `window.open` is routed through `onCreateWindow` into a **single, draggable bottom-right popup**. WebView config is frozen in `initState`; loading `setState` is suppressed after ready. `ForjaInAppWebView` must not forward its `key` onto the child `InAppWebView` (duplicate GlobalKey crash).
