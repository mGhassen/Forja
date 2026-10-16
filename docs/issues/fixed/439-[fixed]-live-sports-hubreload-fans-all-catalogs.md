# 439 — Live Sports HubReload fans every catalog despite Catalog chip

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · progressive schedule · Catalog chip · pack reload

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I439-T01 | HubReload clear-paint remount: PackLoadedPaint must not seed past the force refreshEpoch | ✅ |
| 2 | I439-T02 | Seed Catalog / Schedule chips from Riverpod when layout still has pack defaults | ✅ |
| 3 | I439-T03 | Changelog bullet | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I439-A01 | Catalog = fctv33 → Reload Live Sports pack → leave → open hub: only `Loading fctv33… 1/1` (not 1/N) | ⬜ |

---

## Summary

Reload Live Sports (or open after pack wipe) remounted the feed paint after bumping `refreshEpoch`. New `PackLoadedPaint` adopted that epoch so `force` was false, then cold/default `catalogFilter: all` progressive-scraped every pack. Catalog chip prefs lived in Riverpod but were never restored into LayoutScope on remount (`readCatalogPref` unused).

**Root fix:** clear-paint + `refreshForceNetwork` remounts leave `_appliedRefreshEpoch` one behind so the first bind forces; layout apply seeds Catalog/Schedule from Riverpod when still on pack defaults. Progressive already scopes force to the selected catalog ([436](436-[fixed]-live-sports-refresh-all-catalogs.md)).

**Related:** [436](436-[fixed]-live-sports-refresh-all-catalogs.md) · [435](435-[fixed]-live-sports-rescrape-on-tab-return.md) · feature [live-sports](../../features/live/live-sports.md)
