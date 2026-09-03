# 120 — Player open: free shell tabs / image RAM for decode

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · shell tab cache · ExoPlayer / IPTV · `ShellBus.enterPlayerSurface`  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 4** acceptance |
| **Current slice** | T06–T08: freeze IPTV catalog + cap image RAM while the player is up |

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
| 6 | I120-T06 | IPTV catalog chrome unmounts while `playerSurfaceActive` (screen State kept for Back / I123 focus) | ✅ |
| 7 | I120-T07 | Image-cache trim/cap (16 MB / 80) after `playerSurfaceActive` notify so the IPTV grid is already gone; restore on leave; ShellBody pauses selected-tab tickers | ✅ |
| 8 | I120-T08 | Skip IPTV catalog health probes while the player is up; ATV MediaKit demuxer sample every 8 s when cache is healthy | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I120-A01 | Android TV: IPTV live smooth after Home → details → back to IPTV play (no post-browse stutter from keep-alive tabs) | ⬜ |
| 2 | I120-A02 | Android TV: opening any fullscreen player leaves only the prior shell tab mounted | ⬜ |
| 3 | I120-A03 | Desktop/phone: player open still clears sibling tabs + image cache; mount cap remains 5 | ⬜ |
| 4 | I120-A04 | Android TV: IPTV live play does not hitch from catalog logo decode / health HTTP under the player | ⬜ |

---

## Summary

Lazy tab mount ([RFC-016](../rfc/016-[partial]-lazy-tab-mounting.md)) + LRU ([RFC-024](../rfc/024-[partial]-tab-cache-eviction-stale.md)) keep visited tabs alive for UX. On weak Android TV SoCs, Home feed images + IPTV catalog stay resident while a new Exo/SurfaceView session starts — live IPTV hitch after browsing Home/details.

**Root fix:** give the player max RAM/GPU — tighter TV tab cap, stop hidden-tab tickers, and on every fullscreen player enter unload **other** shell tabs and Flutter’s image cache while keeping the screen that opened the player. IPTV also trims images when the tab is hidden.

**Follow-up (T06–T08):** I120 still left the IPTV catalog **laid out** under the opaque player. `trimImageCacheForPlayback` then made every still-mounted `CachedNetworkImage` refill GPU — a decode hitch mid-play on physical ATV. The IPTV tab now drops catalog chrome (not the screen `State`) while the player is up, image trim waits a frame, the cache stays capped until leave, health probes no-op, and ATV MediaKit slows healthy demuxer FFI.

**Related:** [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) · [RFC-024](../rfc/024-[partial]-tab-cache-eviction-stale.md) · [platforms](../features/getting-started/platforms.md)
