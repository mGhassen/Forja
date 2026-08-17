# RFC-057: Home watch-provider filter

**Status:** partial  
**Depends on:** RFC-023 (shell), RFC-025 (flat cinematic shell)  
**Area:** `apps/forja/lib/shell/`, `apps/forja/lib/features/home/`  
**Version:** v1.4 Atarin

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 9** acceptance · **0 / 1** device smoke |
| **Current slice** | Family aliases shipped — device smoke open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R57-C01 | `ShellBus.homeProviderMenuVisible` + Home re-press toggle/clear | ✅ |
| 2 | R57-C02 | Provider logo strip mounted from `HomeTopBar` (desktop / TV / mobile) | ✅ |
| 3 | R57-C03 | Selected provider logo before Films / TV / Categories | ✅ |
| 4 | R57-C04 | Same-brand TMDB family per chip (Max = HBO / HBO Max + networks; regional SKUs) | ✅ |

---

## Acceptance (1.4.0)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R57-A01 | Re-press Home while on Home shows floating provider strip | ✅ |
| 2 | R57-A02 | Tap provider filters all Home rails via TMDB `with_watch_providers` | ✅ |
| 3 | R57-A03 | Selected logo appears before Films menu; tap selected logo clears filter | ✅ |
| 4 | R57-A04 | Re-press Home while strip open or filter active clears filter + hides strip | ✅ |
| 5 | R57-A05 | Leaving Home hides strip (filter may remain until cleared) | ✅ |
| 6 | R57-A06 | Works on desktop, phone, and Android TV | ⬜ |
| 7 | R57-A07 | Feature doc + changelog updated | ✅ |
| 8 | R57-A08 | Shell widget tests cover re-press + filter toggle | ✅ |
| 9 | R57-A09 | Max (and other chips) union same-brand watch ids + TV networks; Featured pads when the month window is thin | ✅ |

---

## Summary

Expose the existing TMDB watch-provider Home filter (`ShellBus.selectedWatchProviderId` → discover) behind a Netflix-style secondary chrome: re-press Home to open a floating logo strip; pick a service to filter the feed; show that service’s logo before the Films menu; clear via Home re-press or tapping the active logo.

## Goals

1. Discoverable service filter without cluttering the default Home chrome.
2. One filter state for all Home rails (already wired).
3. Parity across shell profiles (desktop rail, TV rail, mobile bottom nav).

## Problem

Provider strip + discover filtering already exist (`ShellTopBar`) but were gated off and not tied to Home re-press UX.

## Contracts

- `null` `selectedWatchProviderId` = unfiltered Home.
- Strip visibility is session UI only (`homeProviderMenuVisible`); not persisted.
- Toggle active provider id clears filter without requiring strip dismiss.
- `ShellBus.onHomeNavRepress` / `onLeaveHomeTab` own the nav chrome state machine.
- Chip id is the chrome key. Discover ORs that service’s family (`WatchProviderFamily`): rebrands / regional SKUs, plus a separate TV `with_networks` query so new originals (e.g. HBO *Lanterns* on Max) show before JustWatch tags them. No Amazon/Apple “channel” add-ons.
