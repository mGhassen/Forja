# 311 — Pack reload eagerly refetches every keep-alive hub

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** KitShell · pack reload · hub feed epoch

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I311-T01 | Off-screen hub on `hubFeedEpoch` → mark stale + pending soft reload only | ✅ |
| 2 | I311-T02 | Pending soft reload runs in `onShellTabRefresh` when the hub is selected | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I311-A01 | Settings → Reload packs while on Forja Packs: no Home/Anime/… feed/rail/layout engine calls until that hub is opened | ⬜ |

---

## Summary

**Reload packs** / **Update** bumps `[PluginRegistry.hubFeedEpoch]` after wiping hub `EngineCache`. Keep-alive hubs (visited earlier, still mounted under `Visibility.maintainState`) listened and immediately re-ran `layout` + page `feed` + rails — even while the user stayed on Settings.

**Root fix:** when the hub tab is not `shellTabVisible`, only set a pending soft-reload flag and `markShellTabStale()`. Soft reload (issue 305 keep-painted + force network) runs when MainScreen selects the hub (`refreshIfStale` → `onShellTabRefresh`). The currently visible hub still soft-reloads immediately.

**Related:** [305](305-[fixed]-home-reload-pack-empty-hero-rails.md)
