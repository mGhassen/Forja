# 419 — Aflem hub only shows the Brstej home page, not the whole site

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** `forja-packs/hubs/aflem` (`brstej.js` · `_layout.js` · `_search.js`) · Aflem tab

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I419-T01 | One rail per Brstej section (22 sections: series by region, Ramadan 2021–2026, films by region, TV shows) plus Latest episodes, Most viewed, and All series | ✅ |
| 2 | I419-T02 | Rails set `maxPages` so scrolling keeps loading past the host's 4-page default | ✅ |
| 3 | I419-T03 | Card parsers read only the page's own grids — the fixed footer of 8 series links and the pinned "featured" / "discover" / "popular" blocks no longer leak into rails, category lists, or search | ✅ |
| 4 | I419-T04 | Pager detection matches `&amp;page=N` (film sections reported no next page) | ✅ |
| 5 | I419-T05 | Films / Series menus filter on `type` so layout `showWhenType` hides the other kind's rails; a chosen Category empties the other section rails | ✅ |
| 6 | I419-T06 | Details opened from an episode or film page: parse the watch page's `.pwr-season-panel` episode list; films get the `MOVIE` badge and a clean title | ✅ |
| 7 | I419-T07 | Host: `PackChromeScope` carries `chromeFilterEpoch` and notifies on change — rails on hubs without a page feed never refetched when Films / Series / Categories changed | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I419-A01 | Manual: Aflem tab shows section rails (Ramadan 2026, Turkish, Arabic films, …) and each rail keeps loading on scroll | ⬜ |
| 2 | I419-A02 | Manual: Films / Series menus and each Category show only matching rails | ⬜ |
| 3 | I419-A03 | Manual: a show opened from Latest episodes lists its episodes and plays; a film opened from a films rail plays | ⬜ |
| 4 | I419-A04 | Manual (Android TV): D-pad walks the rail chain, including past hidden or empty rails | ⬜ |

---

## Summary

The Aflem layout had three rails (spotlight, latest, ranked), and all three loaded the same `moslslat.php` list. Each rail also stopped after 4 pages because the layout set no `maxPages`. Users saw only the newest shows and could not browse the site's sections.

Two parser bugs made the Category filter weak too:

- `brstejParseSerieCards` matched any `series1.php?id=` link. Every Brstej page carries a footer with the same 8 series links, so section pages returned those 8 shows and never reached the real episode cards. Film sections returned the 8 footer shows and no films. Search merged the same 8 shows into every result list.
- `brstejHtmlHasNextPage` required `?page=` or `&page=`. Film sections write `&amp;page=`, so they reported no next page.

Details from a `watch:` id returned no episodes on `main` before this change, because Brstej moved the watch-page episode list to `.pwr-season-panel`.

## Upstream map (Brstej, checked 2026-10-07)

| Source | URL | Cards | Pages |
|--------|-----|-------|-------|
| All series, newest first | `/moslslat.php?page=N` | `article.psd-card` (16) | 178 |
| Section series index | `/cat03.php?cat=X&type=series&page=N` | `ul.pcg-all-series-grid li` (15) | Prestige 85, Arabic 60, Turkish 23, … |
| Section episodes | `/cat03.php?cat=X&page=N` | `ul.pcg-episodes-grid li` (14) | Turkish 2138 |
| Section films | `/cat03.php?cat=X&page=N` | `.pmc-results-grid article.pmc-card` (24) | Arabic 39 |
| Latest episodes | `/new-videos.php?page=N` | `.pln-grid article.pln-card` (24) | 6211 |
| Most viewed | `/topvideos.php?page=N` | `li.col-xs-6` (15) | — |
| Search | `/search.php?keywords=Q&page=N` | `ul.prs-grid article.prs-card` | — |

`category.php` and `cat67.php` redirect to `cat03.php`. Older and smaller sections (Asian, TV, Ramadan 2022, 2021, anime) have a one-page series index that misses shows; those continue into the section's episode grid. The site's anime films section is empty (0 films), so its rail hides.

## Top menu did nothing (host)

On desktop, Films / Series / Categories highlighted but no row changed. A filter change only `setState`s the layout painter. Rails refetch in `didChangeDependencies`, which runs only when an inherited scope they read notifies. `PackChromeScope` notified on page-feed changes, refresh, and hold — not on the chrome filter epoch — and rail params are just `{rail}`, so `didUpdateWidget` saw no change either. Aflem has no page feed, so no rail ever refetched. The scope now carries the filter epoch; `pack_chrome_scope_filter_epoch_test.dart` fails without the comparison and passes with it.

## Known limits

- Latest episodes, Most viewed, and the episode-grid fallback group episodes into shows per page. A show can appear again on a later page under another episode id. A stable show id would need `details` to resolve a title, and the host passes only `id` when it has no seed.

## Related

- [Aflem feature guide](../features/hubs/aflem.md)
