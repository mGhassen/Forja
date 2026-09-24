# 375 — Hub keep-alive keeps fetching after leaving the tab

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja` shell · kit hub painter · EngineService catalog cancel

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **2 / 2** acceptance |
| **Current slice** | Complete |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I375-T01 | `PackLayoutPainter.onShellTabHidden` → `cancelCatalog` + `cancelLiveCatalog` + bump page-feed gen | ✅ |
| 2 | I375-T02 | `cancelCatalog` also `EngineRuntime.abortAll` (stop mid-flight flutter_js / host requests) | ✅ |
| 3 | I375-T03 | `PackLoadedPaint` gate: no new rail/feed bind when `shellTabVisible` is false | ✅ |
| 4 | I375-T04 | Stremio host catalog + MetaRuntime SWR respect `catalogGeneration` on hub hide | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I375-A01 | Leave Stremio (or Home / Live Sports) mid-load for IPTV — no further `[StremioService.getCatalog]` / hub feed logs from the left hub | ✅ |
| 2 | I375-A02 | Return to the hub — last painted rails stay; re-tap / stale refresh can reload | ✅ |

---

## Summary

RFC-024 law: keep-alive must not mean keep-fetching. Visited hubs stay mounted under `Visibility.maintainState`, but `PackLayoutPainter` never cancelled catalog work on hide — Stremio rails, Live Sports scrapes, and Home page-feed kept running while the user was on IPTV.

**Root fix:** on hub hide, bump page-feed gen, `cancelCatalog` (generation + abort flutter_js forks), `cancelLiveCatalog`, and stop `PackLoadedPaint` from starting new binds while `shellTabVisible` is false. Stremio `HostEngineRequest` catalog and MetaRuntime SWR drop results when generation advances.

### Related

- [RFC-024](../../rfc/fixed/024-[fixed]-tab-cache-eviction-stale.md)
- [issue 311](311-[fixed]-pack-reload-eager-hub-refetch.md) (reload must not stampede off-screen hubs)
