# 346 — Sources panel hover status color lost on reopen

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** player Sources · hover probe  
**Reported:** 2026-09-23  
**Fixed:** 2026-09-23

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **5 / 5** fix · **0 / 4** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I346-T01 | Session TTL cache for Sources hover-probe green/red keyed by stream URL | ✅ |
| 2 | I346-T02 | `StremioSourceTile` accepts `probeHealthCache` and paints from it on rebuild | ✅ |
| 3 | I346-T03 | Player Sources panel reads/writes probe cache on hover check | ✅ |
| 4 | I346-T04 | Split TTL: streams / panel UI **1h**, hover status **15m** | ✅ |
| 5 | I346-T05 | Torrents reopen restores fetched provider ids so cache hit does not re-search / wipe rows | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I346-A01 | Hover a Forja/Stremio/Nuvio row until green/red → close Sources → reopen → same left-bar color without re-hover | ⬜ |
| 2 | I346-A02 | Red row: re-hover after reopen still re-probes (recovery path) | ⬜ |
| 3 | I346-A03 | Load Torrents / Forja streams → close → reopen within 1h → same rows, no full re-fetch spinner wipe | ⬜ |
| 4 | I346-A04 | After ~15m, hover status clears but stream rows remain until 1h | ⬜ |

---

## Summary

Hovering a Sources stream row paints a green/red left bar after a soft HTTP probe. Closing and reopening the panel dropped that color because the result lived only on the tile `State`. Torrents also looked “uncached”: optimistic seed painted rows without marking providers fetched, so reopen re-ran search and could clear the list.

**Root fix:** store probe results in `CatalogSourcesSessionCache` · streams / UI TTL **1h** · probe status TTL **15m** · torrents cache stores `fetchedProviderIds` and restores them on seed/ensure so reopen skips re-search.

**Verify:** load streams → hover status → close → reopen → rows + colors still there (status ≤15m, streams ≤1h).
