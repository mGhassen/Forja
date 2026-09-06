# 226 — Live Sports stuck on “Loading catalogs…” after pack update

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · plugin pack update · catalog hydrate  
**Reported:** 2026-09-06

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I226-T01 | Pack-change reload kicks catalog load with `replace: true` so a second `changeNotifier` bump cannot no-op while inflight | ✅ |
| 2 | I226-T02 | Inflight `whenComplete` clears stuck hydrate when serial finished with empty plugin map | ✅ |
| 3 | I226-T03 | Tab show recovers stuck empty hydrate (or dirty settings) even when `_forjaLiveCatalogHydrating` stayed true | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I226-A01 | Update ForjaHQ Live + Catalog packs while Live Sports is open → schedule reloads; no forever “Loading catalogs…” | ⬜ |
| 2 | I226-A02 | Leave Live Sports mid-update / reopen tab → catalogs load (dirty or stuck-hydrate path) | ⬜ |

---

## Summary

Updating packs (often Live then Catalog in one batch) notifies `EngineService.changeNotifier` twice. Live Sports cleared its plugin map and started a lazy catalog load on the first bump; the second bump reset again and called `_kickForjaLiveLazyCatalog()` **without** `replace`, which no-ops while the first future is still in flight. The first future then bailed on a stale `_forjaLiveLoadGen` without clearing `_forjaLiveCatalogHydrating`, leaving an empty map + hydrate spinner forever.

## Root cause

Race between multi-pack `notifyChanged` and non-replace catalog kick + gen-stale early return that skips hydrate cleanup.

## Fix

- `_applyEngineCatalogSettingsChange(reloadNow: true)` always `_kickForjaLiveLazyCatalog(replace: true)`.
- Inflight completion drops hydrate if this serial ended with no registered plugins.
- `onShellTabShown` prefers dirty settings reload and force-kicks stuck empty hydrate.

## Related

- [219](219-[fixed]-plugin-update-green-play-stale-session-cache.md) — pack update session extract cache (separate)
- Logs: `[PluginInstall] ready ForjaHQ Live` then Catalog with no subsequent `catalog-* start` while UI shows Loading catalogs…
