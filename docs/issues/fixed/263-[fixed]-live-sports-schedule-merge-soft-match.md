# Issue 263: Live Sports schedule merge dead / soft-match too weak

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** live sports / schedule merge

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I263-T01 | Restore Catalog=All same-fixture merge in `aggregateLiveFeed` (pack `mergeMatchingEvents`) | ✅ |
| 2 | I263-T02 | Soft-match via `liveTeamPairSoftEqual` + coarse bucket (not exact `matchTextKey` pair keys) | ✅ |
| 3 | I263-T03 | Parse `A - B` titles as vs; skip session dashes (`GP - Practice 2`) | ✅ |
| 4 | I263-T04 | Providers sibling resolve uses the same soft fixture matcher | ✅ |
| 5 | I263-T05 | Unit tests: Barcelona 8→1 collapse; City vs United stay separate | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I263-A01 | Manual: Catalog=All shows one Barcelona/Feyenoord card; Providers still lists sibling catalogs | ⬜ |

---

## Summary

Kit migration dropped schedule-grid merge. The **Merge matching events** toggle remained in the Live Sports hub Setup but did nothing. `aggregateLiveFeed` only deduped by opaque `id`, so each catalog painted its own card for the same kickoff.

Providers soft-match used exact `matchTeamPairKey` / `matchTextKey`, which misses `Feyenoord` ↔ `Feyenoord Rotterdam` and (via token strip) can equate City/United.

**After:** Catalog=All collapses soft-matched fixtures (default on). Unmerged scrape pool still feeds Providers sibling resolve.
