# 319 — Live Sports Stremio Catalog chip loads empty schedule

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · Stremio Catalog · hub `plugin.run`  
**Reported:** 2026-09-23  
**Related:** [241](241-[fixed]-live-sports-stremio-catalog-missing-after-kit.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I319-T01 | `host.plugin.run(stremio:…, catalog)` → `loadLiveStremioCatalogFeed` | ✅ |
| 2 | I319-T02 | Progressive Stremio chip loads rows in Dart then hub reduce (cache) | ✅ |
| 3 | I319-T03 | Changelog — Stremio Live Catalog schedule shows again | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I319-A01 | Manual: Catalog → Flixnest (or other Live Stremio addon) shows schedule rows; log `[LiveStremio] catalog … rows=N` with N ≫ 0 | ⬜ |

---

## Summary

**Symptom:** Live Sports **Catalog →** a Stremio Live addon (e.g. Flixnest / `stremio:https://free.flixnest.app`) painted an empty schedule. Log showed hub feed + `[Live Sports] streams=1` (envelope only) with **no** `[LiveStremio]` / addon catalog fetch.

**Root:** Issue [241](241-[fixed]-live-sports-stremio-catalog-missing-after-kit.md) added `loadLiveStremioCatalogFeed` and pack `stremio:` feed branch (`host.plugin.run(filter, 'catalog')`), but host `_dispatchPluginRun` only looked up pack plugins by id. `stremio:<baseUrl>` missed → `[]`. The loader was dead code.

**Fix:** Catalog action on a `stremio:` id calls `loadLiveStremioCatalogFeed`. Progressive chip path loads those rows in Dart, caches, and hub-reduces (same as host-scraped packs).
