# 120 — Player open: free shell tabs / image RAM for decode

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · shell tab cache · ExoPlayer / IPTV · `ShellBus.enterPlayerSurface`  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I120-T01 | TV mount cap `maxMountedTabsTv = 3` (desktop stays 5) | ✅ |
| 2 | I120-T02 | Hidden shell tabs: `TickerMode(enabled: selected)` (Visibility cannot set `maintainAnimation: false` with `maintainSize`) | ✅ |
| 3 | I120-T03 | `enterPlayerSurface` (0→1): trim `imageCache` + purge sibling mounted tabs (keep screen under player) | ✅ |
| 4 | I120-T04 | IPTV `onShellTabHidden`: trim image cache (keep portal selection) | ✅ |
| 5 | I120-T05 | Unit tests for TV cap + player purge revision / image trim | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I120-A01 | Android TV: IPTV live smooth after Home → details → back to IPTV play (no post-browse stutter from keep-alive tabs) | ⬜ |
| 2 | I120-A02 | Android TV: opening any fullscreen player leaves only the prior shell tab mounted | ⬜ |
| 3 | I120-A03 | Desktop/phone: player open still clears sibling tabs + image cache; mount cap remains 5 | ⬜ |

---

## Summary

Lazy tab mount ([RFC-016](../rfc/016-[partial]-lazy-tab-mounting.md)) + LRU ([RFC-024](../rfc/024-[partial]-tab-cache-eviction-stale.md)) keep visited tabs alive for UX. On weak Android TV SoCs, Home feed images + IPTV catalog stay resident while a new Exo/SurfaceView session starts — live IPTV hitch after browsing Home/details.

**Root fix:** give the player max RAM/GPU — tighter TV tab cap, stop hidden-tab tickers, and on every fullscreen player enter unload **other** shell tabs and Flutter’s image cache while keeping the screen that opened the player. IPTV also trims images when the tab is hidden.

**Related:** [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) · [RFC-024](../rfc/024-[partial]-tab-cache-eviction-stale.md) · [platforms](../features/getting-started/platforms.md)
