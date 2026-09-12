# 276 — Host search engine behind hub kit screen

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `apps/forja/lib/shared/host/search`, `kit_search_*`, Home `host_search`  
**Reported:** 2026-09-12  
**Related:** [RFC-070](../rfc/070-[partial]-catalog-hub-protocol.md) R70-A84–A86 · [RFC-058](../rfc/058-[partial]-structured-search.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **3 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I276-T01 | Port archive Search providers → `HostSearchEngine` + helpers (no SearchScreen UI) | ✅ |
| 2 | I276-T02 | `host_search` → KitSearchScreen progressive host engine; pack hubs keep MetaRuntime | ✅ |
| 3 | I276-T03 | Cmd+F / top-bar `openCatalogSearch`; feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I276-A01 | Home Search shows TMDB structured hits then Stremio addon rows on kit chrome | ✅ |
| 2 | I276-A02 | Anime / Asian Drama Search unchanged (pack `search` only) | ✅ |
| 3 | I276-A03 | Archived `apps/archive/lib/search/` UI not recompiled into Forja | ✅ |

---

## Summary

Archive commit dropped the Search tab and left `host_search` wired to pack-only kit search (no addons). Migrate the **engine/services** onto the host; keep the **screen** as hub [KitSearchScreen].

## Root cause

`bc24ada2d` archived `SearchScreen` and removed the `host_search` → host overlay path without moving progressive TMDB + addon search into the kit host path.

## Fix approach

`shared/host/search/HostSearchEngine` + kit progressive emit; capability `host_search` selects that engine behind the same kit page.
