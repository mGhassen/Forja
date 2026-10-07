# 420 — Arabic hub (Larozaa) misses most of the site; details and half the servers broken

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** `forja-packs/hubs/arabic` (`arabic.js` · `_layout.js` · `_search.js`) · `forja-packs/providers/larozaa.js` · Arabic tab

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I420-T01 | Turkish series section id `turkish-3isk-seriess47` → `…48`; old id kept as a Category alias; `<meta refresh>` stubs are followed so a moved section no longer loads empty | ✅ |
| 2 | I420-T02 | Rails return the whole upstream page (40 cards, was clamped to 24) and read `hasMore` from the site pager | ✅ |
| 3 | I420-T03 | Rails set `maxPages`; new **كل المسلسلات** rail pages `moslslat4.php` (every series) | ✅ |
| 4 | I420-T04 | Feed loads each rail's own page 1 (home-page seeding skipped every section's real page 1); hero uses most viewed instead of repeating latest | ✅ |
| 5 | I420-T05 | Films / Series menus filter on `type` (`showWhenType`); a chosen Category empties the other section rails and its hero sorts by views; clean film / show titles | ✅ |
| 6 | I420-T06 | Search walks up to 4 result pages and ranks title matches first | ✅ |
| 7 | I420-T07 | Details parse the current show page (`h1`, `.ls-description`, `section.ls-season-panel` / `article.ls-card`); a film id opened without `movie` falls back to its film page | ✅ |
| 8 | I420-T08 | Provider: Vidara via `POST /api/stream`; VOE, Vidmoly, Mixdrop, DoodStream via shared hops (`mixdrop.top`, `mxdrop.top`, `dsvplay.com` added to hop hosts) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I420-A01 | Manual: Arabic tab shows every section row (Turkish series not empty) and each row keeps loading on scroll | ⬜ |
| 2 | I420-A02 | Manual: Films / Series menus and each Category show only matching rows | ⬜ |
| 3 | I420-A03 | Manual: a show opened from Latest lists all seasons with the right name and synopsis; a film from Continue Watching opens as a film | ⬜ |
| 4 | I420-A04 | Manual: Sources list Vidara and Mixdrop servers and they play | ⬜ |
| 5 | I420-A05 | Manual: VOE, Vidmoly, DoodStream servers resolve through hops (unreachable from the dev network, so unverified) | ⬜ |

---

## Summary

The Arabic layout already had a row per Larozaa section, but most of the catalog never reached the screen:

- The Turkish series section moved to `turkish-3isk-seriess48`. The old id answers with a `<meta refresh>` stub, which `ctx.fetch` does not follow, so the row was empty.
- Each Larozaa page holds 40 cards. The pack clamped every page to 24, so 16 titles per page were never shown.
- Rails had no `maxPages`, so the host stopped after 4 pages.
- The feed seeded four rails from home-page sections, then `rail` page 2 continued from the section's page 2. Each section's real page 1 was skipped.
- The hero and the first row showed the same `newvideos1.php` list.
- `moslslat4.php` lists every series (56 pages × 40) and was not used.

Details were broken on `main` by Larozaa's show-page redesign: the name came from the first `h2` ("المواسم والحلقات"), there was no synopsis, and a film id opened without the `movie` flag returned an empty show.

The provider resolved 3–5 of 13–16 servers per title. Its generic unpacker only reads pages with a plain or packed `.m3u8` / `.mp4` link.

## Upstream map (Larozaa, checked 2026-10-07)

Live origin `llaroza.homes` (5 redirects from `laaroza.lat`).

| Source | URL | Cards | Pages |
|--------|-----|-------|-------|
| Every series | `/moslslat4.php?page=N` | `ul.lr-series-grid li` (40) | 56 |
| Section | `/category.php?cat=X&page=N` (`&sortby=views`) | `li.col-xs-6` (40) | Arabic series 857, films 39 |
| Latest | `/newvideos1.php?page=N` | `li.col-xs-6` (48) | 1471 |
| Most viewed | `/topvideos1.php?page=N` | `li.col-xs-6` (48) | — |
| Search | `/search.php?keywords=Q&page=N` | `li.col-xs-6` (40) | — |
| Show | `/view-serie1.php?ser=ID` | `section.ls-season-panel` → `article.ls-card` | — |

## Server coverage (one episode, one film)

| Host | Before | After |
|------|--------|-------|
| vidoba, mp4plus, anafast | ✅ unpack | ✅ unpack |
| vidara.to | ⬜ | ✅ `/api/stream` |
| mixdrop.top | ⬜ | ✅ hop |
| voe.sx, vidmoly.net, dsvplay.com | ⬜ | 🔄 routed to hops, unverified |
| okhd, film77, vidspeed, upzur (file-host pages needing a form step) | ⬜ | ⬜ |
| hgcloud, streamhls, bysejikuar (JS loaders) | ⬜ | ⬜ |
| ok.ru | ⬜ | ⬜ (video-unavailable stub) |

## Known limits

- Section series rows, Latest, and Most viewed are episode lists grouped into shows per page. A show can appear again on a later page under another episode id.

## Related

- [Arabic feature guide](../features/hubs/arabic.md)
- [419 — Aflem hub only shows the Brstej home page](419-[open]-aflem-hub-home-page-only.md)
