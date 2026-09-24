# 380 — Pack reload stamps AniList / keep-alive hubs (429)

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** KitShell · pack reload · hub feed epoch · keep-alive visibility

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I380-T01 | Pack wipe `hubFeedEpoch` (`forceNetwork: true`) → pending soft reload only (never scrape now) | ✅ |
| 2 | I380-T02 | `onShellTabHidden` / `Shown` `setState` so `PackChromeScope.shellTabVisible` updates | ✅ |
| 3 | I380-T03 | `PackChromeScope.updateShouldNotify` includes `shellTabVisible` | ✅ |
| 4 | I380-T04 | `LazyViewportGate` + `_loadPage` refuse work while hub tab is hidden | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I380-A01 | Settings → Reload packs with Anime (or Home) previously visited: no `anilist` / hub `rail`/`feed` engine logs until that hub is opened | ⬜ |

---

## Summary

**Reload packs** bumps `hubFeedEpoch` per pack (and `all` when a hub pack version wipes the catalog). Issue [311](311-[fixed]-pack-reload-eager-hub-refetch.md) deferred off-screen hubs, but (1) `forceNetwork` still soft-reloaded a hub whose mixin said visible, and (2) hide never rebuilt `PackChromeScope` / notified dependents — `PackLoadedPaint` and `LazyViewportGate` kept treating keep-alive hubs as on-screen (`maintainSize` geometry), so AniList rails stampeded and hit HTTP 429 while the user stayed on Settings or another hub.

**Root fix:** pack script wipe always flags `_pendingHubFeedSoftReload` + `markShellTabStale()`; soft reload runs only on hub show (`onShellTabRefresh`). Pack **settings** (`forceNetwork: false`) still soft-reload while that hub is selected. Hide/show pushes `shellTabVisible` into chrome; gates refuse off-tab binds.

**Related:** [311](311-[fixed]-pack-reload-eager-hub-refetch.md) · [375](375-[fixed]-hub-keep-alive-keeps-fetching-off-tab.md) · [305](305-[fixed]-home-reload-pack-empty-hero-rails.md)
