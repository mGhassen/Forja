# 236 — Live Sports feed empty after EngineJS-first catalog

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · `EngineService.runCatalog` · `ctx.host.liveFeed`  
**Reported:** 2026-09-08  
**Related:** [234](fixed/234-[fixed]-macos-boot-catalog-feed-jsc-crash.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I236-T01 | Skip EngineJS for `live_match` kit hubs (`needsLiveFeedHost`) — flutter_js only | ✅ |
| 2 | I236-T02 | Live Sports / Cards pack: reject when `host.liveFeed` missing (no empty ok envelope) | ✅ |
| 3 | I236-T03 | KitCategoryBar: listen/read page without dual-watch (markNeedsBuild during build) | ✅ |
| 4 | I236-T04 | Empty list copy: kind `all` is not a kind filter | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I236-A01 | Manual: Live Sports tab shows schedule rows (Catalog All / PPV with events) — no empty list + no markNeedsBuild during build | ⬜ |

---

## Summary

**Symptom:** Live Sports showed **Nothing in this list** / **Tap a kind tab again…** while engine logged `live-sports-hub … action=feed … raw=1`. Also `setState()/markNeedsBuild() called during build` on `KitCategoryBar` while `KitListWidget` built.

**Root cause:**

1. [234](fixed/234-[fixed]-macos-boot-catalog-feed-jsc-crash.md) made catalog **EngineJS-first**. Live Sports `feed` calls `ctx.host.liveFeed.load`. EngineJS has no bridge; the pack returned `[]` as an **ok** envelope, so flutter_js (which has `liveFeed`) never ran.
2. `KitCategoryBar` and `KitListWidget` both `watch`ed `metaFeedCatalogProvider` — flushing the provider mid-list-build dirtied the category bar.

**Fix:** Host skips EngineJS when `plugin.needsLiveFeedHost`; packs reject without `liveFeed`; category bar uses `listenPage` + `readPage` post-frame.
