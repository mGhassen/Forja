# Issue 290: IPTV catalog page — host shelf, pack gets a page

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** IPTV hub · portal engine · flutter_js

## Status at a glance

| | |
|--|--|
| **Progress** | **12 / 12** fix · **0 / 4** acceptance |
| **Current slice** | Host `catalog_page` + file shelf + pack feed — manual QA open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I290-T01 | File+Isolate portal catalog shelf store (scoped) | ✅ |
| 2 | I290-T02 | Host `engine.request('iptv', { action: catalog_page })` — filter/sort/page in Dart | ✅ |
| 3 | I290-T03 | Pack Live/Movies/Series feed uses `catalog_page` only (no full `streams[]` in JS) | ✅ |
| 4 | I290-T04 | Channel scan / favorites / searchChannels via page + `q` / `stream_ids` | ✅ |
| 5 | I290-T05 | Settings clear + LocalDataScope wire for shelf files | ✅ |
| 6 | I290-T06 | Changelog + unit test for page filter/sort | ✅ |
| 7 | I290-T07 | Live category flips re-query `catalog_page` (was paint-filter on first-cat page → empty + jank) | ✅ |
| 8 | I290-T08 | Favorites / Already watched pages: empty `stream_ids` returns empty page (not whole shelf) | ✅ |
| 9 | I290-T09 | Favorites / Watched select: keep synthetic selection (no feed-kinds snap-back) + clear prior page | ✅ |
| 10 | I290-T10 | Live/Movies/Series shelf flip: loading on first visit; restore last paint when that shelf is warm | ✅ |
| 12 | I290-T12 | Search `q`: shelf-wide `hitCategoryIds` + host category-rail hits ([315](fixed/315-[fixed]-iptv-search-no-categories.md)) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I290-A01 | Open IPTV Movies / Series on a large portal — UI stays responsive (no freeze / ANR) | ⬜ |
| 2 | I290-A02 | Category flip + scroll page loads more without re-downloading the whole shelf | ⬜ |
| 3 | I290-A03 | Search matches titles across the shelf; results are paged | ⬜ |
| 4 | I290-A04 | Warm reopen hits disk shelf; flutter_js only receives ≤ pageSize streams | ⬜ |

---

## Summary

Pack cutover moved full Xtream VOD/series catalogs through flutter_js (`jsonEncode` → JSC). Feed paging only trimmed the paint payload — the bridge still injected tens of thousands of rows → freeze / “did not answer”.

**C:** Host owns the shelf (Rust fetch + Dart file/Isolate cache). Pack calls `catalog_page` and receives `categories` + one page of `streams` (+ `hasMore`). Fat categories cannot reintroduce the ANR class.

### Shipped

- `PortalCatalogShelfStore` — scoped file shelves + memory LRU
- `PortalCatalogPage` / `HostEngineRequest` action `catalog_page`
- IPTV pack `iptvFetchCatalogPage` for feed, Channels scan, Live Sports channel match
- Settings → clear portal caches wipes shelf files

### Related

- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md) — pack product; generic `engine.request` / disk
- [288](288-[open]-iptv-catalog-qol-iso-v1536.md) — catalog QoL after pack cutover
