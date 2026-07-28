# 122 — Android TV IPTV player lost D-pad (align with movie player)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV player · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I122-T01 | IPTV player chrome: FocusNodes + ReadingOrderTraversal (no catalog-row graph) like movie/Exo | ✅ |
| 2 | I122-T02 | Claim Play focus on boot / show chrome; live ←/→ reveals chrome | ✅ |
| 3 | I122-T03 | Exo PlayerView / SurfaceView `focusable=false` so native view cannot steal leanback keys | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I122-A01 | Android TV IPTV live: after open, D-pad lands on Play; ←/→ moves chrome; Select toggles play/pause | ⬜ |
| 2 | I122-A02 | Android TV IPTV VOD: chrome hidden ←/→ seeks ±10s; ↑ Back · ↓ Play (same as movie player) | ⬜ |

---

## Summary

On **Android TV**, the IPTV player remote felt dead: chrome used the catalog-row focus graph instead of the movie player’s FocusNode + reading-order traversal, Play was not claimed on boot, and Media3 `PlayerView` / SurfaceView could take native focus so Flutter never saw D-pad keys.

**Root fix:** match the movie/Exo player path (Play/Back FocusNodes, `FocusTraversalGroup`, claim Play on ready) and mark Exo `PlayerView` non-focusable.

## Related

- [110](110-[open]-android-tv-iptv-player-top-bar-dpad.md) — IPTV top-bar Player chrome
- [104](104-[open]-android-tv-live-matches-embed-dpad.md) — Live Matches embed D-pad
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../features/playback/player.md)
