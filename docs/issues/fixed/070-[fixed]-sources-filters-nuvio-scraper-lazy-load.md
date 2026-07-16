# 070 — Sources: providers in Filters; lazy Nuvio scrapers

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** media-details Sources · player Sources · `torrent_source_filters.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 8 / 8** fix · **2 / 5** acceptance |

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
| 6 | I70-T06 | Remove the presentation-only 10-row cap so Torrents and Stremio show every fetched row | ✅ |
| 7 | I70-T07 | Nuvio starts one selected scraper and **Load next provider** runs one additional scraper | ✅ |
| 8 | I70-T08 | Cache Nuvio rows with attempted scraper IDs so reopen preserves lazy-fetch progress | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I70-A01 | Unit: kind filter has no All; `kSourcesListPageSize` is 10; Load more labels remaining | ✅ |
| 2 | I70-A02 | Manual: open Sources with multiple kinds → Torrents (or Nuvio/Stremio fallback); Filters shows Providers; no horizontal provider chip row | ⬜ |
| 3 | I70-A03 | Manual: 25+ results → first 10 then Load more; changing filter/kind resets to 10 | ⬜ |
| 4 | I70-A04 | Unit: next Nuvio fetch chooses the first selected, unfetched scraper; footer reports remaining providers | ✅ |
| 5 | I70-A05 | Manual: opening Nuvio runs one scraper; each **Load next provider** runs exactly one more | ⬜ |

---

## Summary

Sources panels previously offered an **All** kind and horizontal provider/addon chips (including **All** for Stremio). Providers now live under **Filters → Providers**, and kinds are Torrents / Stremio / Nuvio only (default Torrents).

The first implementation also capped already-fetched rows in groups of 10 (I70-T04/T05). That presentation-only pagination was removed by I70-T06. Torrents and Stremio now render their complete fetched response. Nuvio is genuinely lazy at its available backend boundary: opening Nuvio runs one scraper, and **Load next provider** starts exactly one additional selected scraper. A Nuvio scraper itself returns one complete response and has no inner page API.
