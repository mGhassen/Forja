# 068 — Catalog Sources panel: TTL cache, lazy kind load, per-kind reload

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** media-details Sources · player Sources · `catalog_sources_session_cache.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6 / 6** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I68-T01 | Session TTL cache for Torrents / Stremio / Nuvio keyed by title + episode | ✅ |
| 2 | I68-T02 | Load a kind only when that kind chip is selected (no prefetch of other kinds) | ✅ |
| 3 | I68-T03 | Reopen Sources within TTL reuses cache (details + player) | ✅ |
| 4 | I68-T04 | Per-kind reload control forces network refetch for that category | ✅ |
| 5 | I68-T05 | Default kind is a single category (not All) when multiple kinds enabled | ✅ |
| 6 | I68-T06 | Closing Sources cancels in-flight Torrents / Stremio / Nuvio fetches | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I68-A01 | Open Torrents → only torrent search runs; switch to Stremio → only then Stremio fetches (if cache miss) | ⬜ |
| 2 | I68-A02 | Close and reopen Sources within 30 minutes → same kind shows cached rows without a new search | ⬜ |
| 3 | I68-A03 | Reload on Torrents / Stremio / Nuvio refetches that kind only | ⬜ |
| 4 | I68-A04 | Close Sources while a category is still loading → fetch stops (no more results after close) | ⬜ |

---

## Summary

Opening the right-side **Sources** panel (media details or player) re-fetched Torrents, Stremio, and Nuvio every time — including prefetch of kinds that were not selected. That is too much scraper traffic for one panel open.

**Fix:** in-memory session cache with a 30-minute TTL per title/episode and kind (`CatalogSourcesSessionCache`); fetch only the selected kind on open/switch; refresh icon on each kind chip bypasses cache for that category only. Default open kind is a single category (Torrents when available), not **All**.
