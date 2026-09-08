# 246 — Home shows “tmdb did not answer layout” on cold open; Retry works

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `KitShell`, `MetaRuntime`, splash / hub boot prefetch  
**Reported:** 2026-09-08

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I246-T01 | Defer KitShell first `layout` until `ShellBus.splashDismissed` (MainScreen mounts under splash Offstage) | ✅ |
| 2 | I246-T02 | Join pack hydrate via `PluginInstallCoordinator.waitUntilIdle` before layout (early continue race) | ✅ |
| 3 | I246-T03 | MetaRuntime: one retry when `runCatalog` returns null before “did not answer” | ✅ |
| 4 | I246-T04 | MainScreen `_tabWithKey` keeps `packSourceUrl` on KitShell | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I246-A01 | Manual: cold open Home several times — no “did not answer layout”; skeleton then rails (or cache hit) | ⬜ |

---

## Summary

Opening the app often showed **tmdb did not answer layout** with **Retry**. Retry always worked.

## Root cause

`SplashScreen` keeps `MainScreen` mounted under `Offstage` for the whole splash. `KitShell.initState` called `_loadLayout()` immediately — before pack hydrate / hub prefetch finished.

`EngineService.runCatalog` then returned `null` (plugin/scripts not ready, or mid-boot miss). `MetaRuntime` surfaced `$pluginId did not answer $action`. Splash prefetch could later succeed into `MetaCache`, but KitShell already stuck on the error panel and did not reload when nothing bumped `PluginRegistry.changeNotifier` (common when packs were already on disk).

## Fix

1. First layout waits for splash dismiss (prefetch already warmed cache on the happy path).
2. Before layout, join an in-flight boot hydrate if the user dismissed early.
3. One short retry on catalog `null` before the error envelope.
4. Preserve `packSourceUrl` when MainScreen keys a hub tab.

## Related

- [hub_boot_prefetch.dart](../../../apps/forja/lib/app/hub_boot_prefetch.dart)
- [Home](../../features/movies-tv/home.md)
