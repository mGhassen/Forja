# 204 — Home rails show the same title across rows

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Home · catalog rails · `home_rail_dedupe.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **3 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I204-T01 | Claim titles by Home visual rail order (`mediaType:id`) | ✅ |
| 2 | I204-T02 | Over-fetch 2 TMDB pages per rail and backfill to display cap | ✅ |
| 3 | I204-T03 | Continue Watching claims without hiding itself; Trakt calendars ignore claim | ✅ |
| 4 | I204-T04 | Unit tests for claim + backfill | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I204-A01 | A title in the hero does not reappear in Featured / Popular / lower discovery rails | ✅ |
| 2 | I204-A02 | After a title is removed from a lower rail, another unused title from that rail’s pool fills the slot (row does not shrink for overlap alone) | ✅ |
| 3 | I204-A03 | Continue Watching and Trakt upcoming still show their titles even if also claimed elsewhere | ✅ |

---

## Summary

Home discovery rails (hero, Featured, Popular, mood, Because, Trakt recs, New Releases, genre rows) pulled overlapping TMDB popularity pools, so the same poster repeated down the page. Deduping without refill would leave short rows.

**Fix:** walk rails in visual order, claim shown `mediaType:id` keys, and refill each exclusive rail from a 2-page pool up to the display cap. Continue Watching still shows in-progress titles and claims them so they do not reappear below. Trakt calendar rails stay overlay-only (no claim).
