# 421 — كرتون and Kids hubs show only the first page of their catalogs

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** `forja-packs/hubs/cartoon` (`cartoon.js` · `_layout.js`) · `forja-packs/hubs/kids` (`kids.js` · `_layout.js`) · كرتون and Kids tabs

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I421-T01 | كرتون: rails page through all grouped series (24 per page, `hasMore`); terms memoised per VM | ✅ |
| 2 | I421-T02 | كرتون: recently updated rail reads 4 × 100 recent episodes per page (was 1–2 shows); new **كل المسلسلات (أ - ي)** rail; letter filter applies to every rail and folds أ/إ/آ | ✅ |
| 3 | I421-T03 | Kids: newest series page `cartoon.php?next=N` (55 pages), films page `movies.php?next=N` (14 pages) | ✅ |
| 4 | I421-T04 | Kids: letter filter returns the whole `N-tri.html` page, paged 24 at a time (was clamped to 24); new A–Z rail, one rail page per letter | ✅ |
| 5 | I421-T05 | Kids: Films / Series menus filter on `type` (`showWhenType`) | ✅ |
| 6 | I421-T06 | Kids details: a show's seasons come from its letter page (cards and Continue Watching ids had partial or no season lists); repeated season pages de-duplicated; film titles drop "فيلم" | ✅ |
| 7 | I421-T07 | Both: `maxPages` on rails; feed returns each rail's own page 1 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I421-A01 | Manual: كرتون rows keep loading past 24 and the A–Z row reaches the last series | ⬜ |
| 2 | I421-A02 | Manual: Kids rows keep loading (series past page 1, films past 21) and the A–Z row walks all letters | ⬜ |
| 3 | I421-A03 | Manual: Kids Films / Series / a letter change the rows | ⬜ |
| 4 | I421-A04 | Manual: Kids SpongeBob from Continue Watching lists all 11 seasons and plays | ⬜ |

---

## Summary

### كرتون (DimaToon)

The pack already fetched all 190 season terms (112 series) from WP REST, then every rail returned the first 24 with no `hasMore`. The host fell back to `items ≥ pageSize`, asked for page 2, and got the same 24 again. 88 series never showed.

The newly-updated rail read 72 recent episodes; daily uploads cluster on one or two shows, so it showed one card. The letter filter compared the raw first character, so ا missed titles starting with أ or إ.

### Kids (Dimakids)

Rails read only `cartoon.php` and `movies.php` page 1 (21 cards each), clamped to 24. The site pages with `?next=N`: 55 series pages (~1,150 season cards) and 14 film pages (~290 films). Letter pages (`N-tri.html`) list every series under a letter (up to 289 cards), and the pack clamped those to 24 too.

Details took a show's season list from the card. Cards from one page miss seasons on other pages, and Continue Watching sends only the id; that path searched page 1 of `cartoon.php` and could not find most shows (SpongeBob opened with 25 episodes instead of 341).

## Upstream map (checked 2026-10-07)

| Site | Source | Notes |
|------|--------|-------|
| DimaToon | `/wp-json/wp/v2/cartoon` | 190 season terms, `X-WP-TotalPages` |
| DimaToon | `/wp-json/wp/v2/cartoon-episode` | 7,018 episodes; `cartoon-movie` is empty |
| Dimakids | `/cartoon.php?next=N` | 21 per page, 55 pages |
| Dimakids | `/movies.php?next=N` | 21 per page, 14 pages |
| Dimakids | `/{0-26}-tri.html` | every series under one letter, unpaged; letters sum to the full catalog |

## Providers

No change needed. DimaToon: 6/6 sampled episodes across the catalog return a direct MP4 that answers 206. Dimakids: 8/8 sampled episodes and films return a tokenized MP4 (`tkn` / `ua` / `ips`) that answers 206 with the provider's headers.

## Known limits

- Kids A–Z rail pages are whole letters, so the ا page adds ~240 cards at once.
- Kids films have no letter pages; with a letter selected the films rail stays hidden.

## Related

- [كرتون feature guide](../features/hubs/cartoon.md)
- [Kids feature guide](../features/hubs/kids.md)
- [419 — Aflem](419-[open]-aflem-hub-home-page-only.md) · [420 — Arabic](420-[open]-arabic-hub-larozaa-coverage.md)
