# 251 — Live Sports schedule empty while Streamed logs streams=N

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · `runLiveFeed` · `metaFeedCatalogProvider`  
**Reported:** 2026-09-09  
**Related:** [237](fixed/237-[fixed]-live-sports-catalog-resolve-jsc-crash.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I251-T01 | Nest flag only around hub `liveFeed.load` bridge (`withHubLiveFeedBridge`) | ✅ |
| 2 | I251-T02 | `runLiveFeed` skip flutter_js only when nest flag + depth — siblings queue | ✅ |
| 3 | I251-T03 | Changelog — Live Sports schedule shows Streamed rows again | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I251-A01 | Manual: open Live Sports — Streamed matches in 24h window paint (not empty while log shows `[Streamed] streams=N`) | ⬜ |

---

## Summary

**Symptom:** Engine log `[Streamed] streams=310` (or similar) while Live Sports list showed **0** / empty. Interleaved `catalog-* skip flutter_js nested under liveFeed` during hub open.

**Root:** [237](fixed/237-[fixed]-live-sports-catalog-resolve-jsc-crash.md) skipped flutter_js whenever `_flutterJsDepth > 0`. That correctly avoids deadlock for hub JS `liveFeed.load` → `aggregateLiveFeed` → `runLiveFeed`. It also fired for **sibling** scrapes (`metaFeedCatalogProvider` while hub `layout` held flutter_js), so catalogs returned `[]` and the progressive list finished empty. A later top-level Streamed scrape still logged `streams=310` but never painted.

**Fix:** Mark true bridge nesting with `withHubLiveFeedBridge` in `_dispatchLiveFeed`. Skip flutter_js only when that flag is set **and** depth > 0. Sibling `runLiveFeed` calls queue on the flutter_js mutex instead of returning empty.

**Note:** `[Live Sports] streams=1` is the hub **envelope** object length in the invoker log, not the schedule row count.
