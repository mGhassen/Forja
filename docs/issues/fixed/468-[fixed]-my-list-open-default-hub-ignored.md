# 468 — My List type default hub ignored on open

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android · My List · open hub binding  
**Reported:** 2026-10-23 (manual — settings stick, open still uses first hub)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

User sets **Open hubs** defaults on My List (Films / Series / Anime / Asian Drama). The settings row keeps the choice. Opening a TMDB bookmark still opens the first details hub for that type (often Home), as if the default were never saved.

## Root cause

`ListOpenBinding.resolveStored` treated TMDB (or any surface) + `pluginIdForEngineType` as a “stored” bind. That short-circuited before `resolveDefault` / `ListOpenPrefs`, so type defaults never ran for typical rows without a per-title `pluginId`.

Evidence: `list_open_binding.dart` (former `resolveStored` surface branch) · `list_open_flow.dart` order stored → default.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I468-T01 | `resolveStored` = row `pluginId` only; move first-hub to `resolveEngineFallback` after defaults | ✅ |
| 2 | I468-T02 | Unit test: TMDB open without `pluginId` is not stored; changelog + feature copy | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I468-A01 | Host unit: TMDB row without `pluginId` → `resolveStored` null | ✅ |
| 2 | I468-A02 | Manual: set Films default to a non-first hub → My List film opens that hub; Open with… still overrides | ⬜ |

## Links

- [RFC-108](../../rfc/fixed/108-[fixed]-my-list-open-hub-binding.md) (R108-A13)
- [400](../400-[open]-my-list-open-with-hub-checkbox.md) (per-title Open with… — separate)
