# 314 — Live Sports settings change wipes schedule feed cache

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · pack settings · feed cache

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I314-T01 | `bumpHubFeedEpoch(forceNetwork:)` — pack wipe true, settings soft false | ✅ |
| 2 | I314-T02 | Pack soft reload respects forceNetwork (keep `live_sports.feed`) | ✅ |
| 3 | I314-T03 | Pack field `reloadHub: false` for paint-only settings (`matchOpen`) | ✅ |
| 4 | I314-T04 | Unit tests: settings soft bump keeps feed slots; open-mode skips epoch | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I314-A01 | Change Open matches in → return to Live Sports: no `Loading … N/M` scrape chip; schedule stays painted | ⬜ |

---

## Summary

Changing Live Sports **Open matches in** (or other hub Setup fields) while the Live Sports tab was keep-alive bumped `hubFeedEpoch`. On return, soft reload always ran with `forceRefresh: true`, which **invalidated** the whole `live_sports.feed` namespace and re-scraped every catalog (`Loading StreamFree… 6/10`).

**Root fix:** pack settings soft-rebind with `forceNetwork: false` (re-reduce from warm scrapes). Paint-only fields declare `reloadHub: false` so only `PackSettingsStore.revision` bumps (open-mode gate). Pack wipe / Reload packs still force network.

**Related:** [311](311-[fixed]-pack-reload-eager-hub-refetch.md) · [305](305-[fixed]-home-reload-pack-empty-hero-rails.md) · feature [live-sports](../../features/live/live-sports.md)
