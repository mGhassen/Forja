# 145 — macOS Live Matches embed: WebKit fullscreen SIGTRAP

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `features/live_matches/` embed WebView (macOS WKWebView)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I145-T01 | macOS: deny HTML5/WK fullscreen (`iframeAllowFullscreen: false`, strip `fullscreen` from iframe `allow`) | ✅ |
| 2 | I145-T02 | Desktop: do not call `windowManager.setFullScreen` from `onEnterFullscreen` / `onExitFullscreen` (chrome + dblclick only) | ✅ |
| 3 | I145-T03 | Exit document fullscreen in `_stopEmbedMediaJs` before blanking iframes | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I145-A01 | macOS: Streamed live embed — play ≥30s, dblclick fullscreen on/off, exit player — no SIGTRAP / process death | ⬜ |

---

## Summary

Crash report (1.3.114, macOS 26.5): `EXC_BREAKPOINT` / PAC IB trap on main thread:

`WebKit::WebFullScreenManagerProxy::beganEnterFullScreen` → completion → `-[WKFullScreenWindowController dealloc]`.

**Symptom:** App dies while watching a Streamed (or other) Live Matches WebView embed — often around HTML5 fullscreen enter/exit.

**Root:** Embed iframe allowed HTML5 fullscreen. WK created `WKFullScreenWindowController`. Forja also wired `onEnterFullscreen` → `windowManager.setFullScreen(true)`, racing WebKit’s own fullscreen lifecycle. Dealloc of the controller while `beganEnterFullScreen` completion was still live → PAC trap (freed poison `0xa1a1a1a1` / `0xa3a3a3a3` in registers). Distinct from [049](049-[open]-live-embed-ad-hijack-crash.md) (ad main-frame / rebuild) and [058](fixed/058-[fixed]-live-embed-audio-continues-after-exit.md) (exit audio).

**Fix (shipped in code):** On macOS, block HTML5/WK fullscreen permissions so `WKFullScreenWindowController` is never created. On all desktop, host fullscreen stays on chrome / dblclick (`windowManager`) only — WebView fullscreen callbacks only update local `_isFullscreen`. Teardown exits document fullscreen before blanking.
