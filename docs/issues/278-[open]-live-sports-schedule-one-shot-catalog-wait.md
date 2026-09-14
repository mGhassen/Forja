# 278: Live Sports schedule waits for every catalog before painting

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports / catalog feed

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I278-T01 | Host progressive catalog fan-out (`LiveScheduleFeedSource`) | ✅ |
| 2 | I278-T02 | Pack `feed` reduce path when `params.rows` present | ✅ |
| 3 | I278-T03 | Wire `readFeedBusy` scrape chip (`Loading … i/n`) | ✅ |
| 4 | I278-T04 | Manual QA: first catalog paints before last finishes | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I278-A01 | Schedule rows appear after the first catalog returns (not only when all finish) | ⬜ |
| 2 | I278-A02 | Top bar shows scrape progress (`Loading ESPN… 2/10`) while catalogs load | ⬜ |

---

## Summary

After RFC-109 moved schedule aggregate into pack `_feed.js`, hub `feed` became a single Promise that sequential-chains every `plugin.run(…, 'catalog')` and only returns once. UI waited on that one-shot envelope.

**Root fix:** host owns catalog fan-out (same shape as Providers / RFC-105). After each catalog, host calls hub `feed` with `params.rows` (reduce/merge/shape only) and paints. Pack keeps Stremio + legacy aggregate when `rows` is absent.

Related: [RFC-105](../rfc/fixed/105-[fixed]-live-providers-plugin-search.md) · [RFC-109](../rfc/109-[open]-forja-pack-product-host.md) · feature [live-sports](../features/live/live-sports.md)
