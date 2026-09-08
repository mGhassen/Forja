# 241 — Live Sports Stremio Catalog + Providers missing after kit

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · Catalog · Stremio · RFC-050  
**Reported:** 2026-09-08  
**Related:** [050](../rfc/050-[open]-stremio-addon-feature-targets.md) · [240](240-[fixed]-live-sports-providers-missing-sibling-resolvers.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I241-T01 | Catalog picker lists live-targeted Stremio addons (`stremio:<baseUrl>`) | ✅ |
| 2 | I241-T02 | Selecting a Stremio Catalog chip loads that addon’s sport schedule via liveFeed | ✅ |
| 3 | I241-T03 | Providers on a Stremio schedule row resolves `/stream` directly (no Forja sibling delay) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I241-A01 | Manual: enable Live on a sports Stremio addon → Catalog shows addon name → pick it → schedule fills | ⬜ |
| 2 | I241-A02 | Manual: tap a Stremio schedule row → Providers lists playable HLS rows | ⬜ |

---

## Summary

**Symptom:** With Stremio sports addons enabled for Live, Live Sports **Catalog** had no addon chips and Providers showed no Stremio streams for those schedules.

**Root cause:** Kit migration (`KitLiveBoot` / `aggregateLiveFeed`) only registered Forja Live pack catalogs. RFC-050 Catalog chips (`stremio:<baseUrl>`) and per-addon schedule load were never ported.

**Fix:** `live_stremio_catalog.dart` + Catalog options append + feed branch for Stremio chips; Providers short-circuits to `/stream` when the row is already a Stremio meta.
