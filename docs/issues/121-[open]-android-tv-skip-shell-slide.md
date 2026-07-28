# 121 — Android TV: skip shell slide transitions (API 24 jank)

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · shell routes · IPTV player boot  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I121-T01 | ATV: `slideShellRoute` / `slideRoute` / trailer / fade → `Duration.zero` | ✅ |
| 2 | I121-T02 | IPTV player: `waitForRouteTransition` before Exo/MediaKit boot | ✅ |
| 3 | I121-T03 | ATV: IPTV catalog `AnimatedSwitcher` + search bar `AnimatedAlign` → `Duration.zero` | ✅ |
| 4 | I121-T04 | IPTV: defer boot/`waitForRouteTransition` to post-frame (ModalRoute.of illegal in `initState`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I121-A01 | Android 7 / leanback: opening details or IPTV player has no sliding stutter (instant cut) | ⬜ |
| 2 | I121-A02 | Desktop/phone: 350ms shell slide unchanged | ⬜ |

---

## Summary

On weak Android TV SoCs, a **350ms opaque slide** runs while the new screen’s `initState` already starts network, image decode, and (IPTV) player open — the animation stutters.

**Fix:** cut shell/player route transitions to zero on Android TV; defer IPTV codec boot until the route animation completes (no-op when duration is zero). Desktop/phone keep the slide.

**Regression (I121-T04):** calling `waitForRouteTransition` synchronously from IPTV `initState` threw (`ModalRoute.of` before initState completed) and aborted player boot on Android TV. Boot now starts in a post-frame callback, matching VOD.

**Related:** [120](120-[open]-android-tv-player-memory-purge.md) · [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) · [platforms](../features/getting-started/platforms.md)
