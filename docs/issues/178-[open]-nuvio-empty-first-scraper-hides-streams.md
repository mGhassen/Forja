# 178 — Nuvio empty first scraper hides later streams

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** media-details Sources · player Sources · Nuvio

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **5 / 7** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I178-T01 | Sequential Nuvio walk skips empty scrapers until one returns rows (details + player) | ✅ |
| 2 | I178-T02 | Missing chip-selection KV defaults to all enabled scrapers (empty saved list stays none) | ✅ |
| 3 | I178-T03 | Unit: `shouldContinueNuvioScraperWalk` / `resolveNuvioSelectedScraperIds` | ✅ |
| 4 | I178-T04 | All / selected walk loads remaining scrapers in batches of 5 until the selected set is exhausted (details + player) | ✅ |
| 5 | I178-T05 | Unit: `nextNuvioScraperBatch` size 5; walk continues while pending remain | ✅ |
| 6 | I178-T06 | Settings → Sources → Nuvio **Select All by default**; off hydrates none selected | ✅ |
| 7 | I178-T07 | Nuvio All tap when already selected clears every scraper and cancels the load (details + player) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I178-A01 | Unit: walk continues only when sequential, empty, and pending remain; chip tap is one-shot | ✅ |
| 2 | I178-A02 | Unit: missing selection → all enabled; saved `[]` → none; stale ids dropped | ✅ |
| 3 | I178-A03 | Manual: open Nuvio with All lit on a movie — AllAnime empty does not leave the list empty when Cineby has streams | ⬜ |
| 4 | I178-A04 | Unit: next batch is 5 unfetched selected ids, then the remainder | ✅ |
| 5 | I178-A05 | Manual: All selected loads every selected scraper in groups of 5 without tapping Cineby | ⬜ |
| 6 | I178-A06 | Unit: missing selection + `selectAllDefault: false` → none | ✅ |
| 7 | I178-A07 | Unit: All tap when all selected → empty; otherwise select every enabled id | ✅ |

---

## Summary

[177](177-[open]-sources-selected-provider-lazy-fetch.md) I177-T03 stopped Nuvio from auto-chaining every selected scraper on open. Opening then ran **only** the first selected scraper in manifest order. All-in-One-Nuvio lists **AllAnime** first; on a movie that returns `[]`, the panel showed **No streams found** while Cineby (and the rest) stayed unfetched until a chip tap.

Missing `nuvio_sources_selected_scrapers_v1` also hydrated as `[]`, so first run fetched nothing until the user picked a scraper.

**Root fix (T01–T03):** sequential open / All walk continues while the list is empty and selected scrapers remain; stop at the first scraper that returns rows. A specific chip tap stays one-shot. First-run (key missing) selects every enabled scraper; an explicit saved empty list still means none.

**T04:** stopping at the first non-empty scraper was still wrong — All selected must load **every** selected scraper. Walk now runs remaining selected scrapers in parallel batches of 5 until the selected set is exhausted. Chip tap stays one-shot.

**T06:** Settings → Sources → Nuvio **Select All by default** (on by default). Off hydrates no scrapers selected until you pick chips. Toggling applies immediately to the saved chip set.

**T07:** Nuvio **All** tap when already selected clears every scraper and cancels an in-flight batch — same toggle as Torrents **All**.

**Related:** [177](177-[open]-sources-selected-provider-lazy-fetch.md) · [070](fixed/070-[fixed]-sources-filters-nuvio-scraper-lazy-load.md)
