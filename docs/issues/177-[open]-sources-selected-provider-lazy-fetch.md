# 177 — Sources: fetch only the selected provider / addon / scraper

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** media-details Sources · player Sources

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I177-T01 | Stremio `getStreams` only for the selected addon chip (details + player) | ✅ |
| 2 | I177-T02 | Torrent search `enabledProviders` = selected chip (All = all enabled) | ✅ |
| 3 | I177-T03 | Nuvio does not auto-chain remaining scrapers; tap chip / All loads one | ✅ |
| 4 | I177-T04 | Default Torrents chip is first enabled indexer, not All | ✅ |
| 5 | I177-T05 | Unit: `enabledForChip` / `missingEnabledForChip` / default chip | ✅ |
| 6 | I177-T06 | Chip switch aborts in-flight fetch; return resumes (not marked fetched) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I177-A01 | Open Sources → Stremio: only the selected addon is requested; tap another addon to fetch it | ⬜ |
| 2 | I177-A02 | Open Sources → Torrents: only the first indexer is searched; tap YTS → YTS only; tap All → remaining indexers | ⬜ |
| 3 | I177-A03 | Open Sources → Nuvio with All lit: one scraper runs; tap another lit scraper to load it (does not deselect) | ⬜ |
| 4 | I177-A04 | Switch chip mid-load: previous search stops; tap it again and it continues | ⬜ |

---

## Summary

Stremio fanned out `getStreams` to every installed addon, then chips filtered the pile. Torrents searched every Settings-enabled indexer, then chips filtered. Nuvio already fetched one scraper at a time but auto-chained through the whole selected set (All by default).

**Root fix:** fetch only the selected chip. Cached rows stay; switching chips fetches that provider if it is missing. Nuvio All no longer walks every scraper on open. Switching chips mid-load aborts the in-flight indexer/addon/scraper (not marked complete); tapping it again continues.

**Related:** [070](fixed/070-[fixed]-sources-filters-nuvio-scraper-lazy-load.md) (Nuvio lazy start) · [RFC-054](../rfc/054-[partial]-torrent-search-providers.md)
