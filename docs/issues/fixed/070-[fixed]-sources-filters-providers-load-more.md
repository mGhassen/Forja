# 070 — Sources: no All chips; providers in Filters; Load more pagination

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** media-details Sources · player Sources · `torrent_source_filters.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **1 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I70-T01 | Remove top-level **All** kind and provider/addon **All** chips (details + player) | ✅ |
| 2 | I70-T02 | Default kind Torrents → Nuvio → Stremio; load only the selected kind | ✅ |
| 3 | I70-T03 | Move Forja/Jackett/Prowlarr, Stremio addons, and Nuvio scrapers into Filters → Providers | ✅ |
| 4 | I70-T04 | Show first 10 filtered rows with **Load more** (+10); reset limit on kind/provider/search/sort/filter change | ✅ |
| 5 | I70-T05 | Unit/widget coverage for no-All kinds, page size, Load more label | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I70-A01 | Unit: kind filter has no All; `kSourcesListPageSize` is 10; Load more labels remaining | ✅ |
| 2 | I70-A02 | Manual: open Sources with multiple kinds → Torrents (or Nuvio/Stremio fallback); Filters shows Providers; no horizontal provider chip row | ⬜ |
| 3 | I70-A03 | Manual: 25+ results → first 10 then Load more; changing filter/kind resets to 10 | ⬜ |

---

## Summary

Sources panels previously offered an **All** kind and horizontal provider/addon chips (including **All** for Stremio). That made long lists hard to scan. Providers now live under **Filters → Providers**, kinds are Torrents / Stremio / Nuvio only (default Torrents), and the list pages in batches of 10 with **Load more**.
