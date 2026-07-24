# 104 — Android TV Live Matches embed: Play / Back / player D-pad

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Live Matches · embed WebView player

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I104-T01 | TV embed chrome: focusable Back (↑ from controls) + bottom Play/Pause · Mute · Fullscreen | ✅ |
| 2 | I104-T02 | Embed media bridge (`postMessage` / `__forjaMedia`) so Flutter Play/Pause/Mute drive iframe media | ✅ |
| 3 | I104-T03 | Initial TV focus lands on Play; Back exits fullscreen first then player; native IPTV Live path keeps player D-pad | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I104-A01 | Android TV: after opening a Live Matches embed, D-pad focus is on Play; Select toggles play/pause | ⬜ |
| 2 | I104-A02 | ↑ from Play focuses Back; Select on Back exits the embed (audio stops) | ⬜ |
| 3 | I104-A03 | ←/→ moves Mute / Fullscreen; native PPV→IPTV player still has its control row D-pad | ⬜ |

---

## Summary

Live Matches embed used a WebView platform view that stole the remote. Only Back was focus-pinned; there was no Flutter Play control or player D-pad row, so users could not Select-to-play or pause after launch.

**Root cause:** Focus stayed on Back only; playback relied on autoplay JS with no TV chrome for Play/Pause/Mute/Fullscreen.

**Fix:** TV-only bottom chrome (Play/Pause · Mute · Fullscreen) + Back with ↑/↓ edges; JS bridge so chrome commands reach wrapper and embed iframes. Native IPTV path (resolved PPV URL) already has player D-pad.
