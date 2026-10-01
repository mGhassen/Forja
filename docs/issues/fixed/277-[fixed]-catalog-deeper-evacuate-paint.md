# 277 — Catalog deeper evacuate (search / section / list paint)

**Priority:** P1  
**Severity:** Medium  
**Status:** fixed  
**Area:** `packages/forja_foundation`, `apps/forja/lib/shared/shell`  
**Reported:** 2026-09-13  
**Related:** [271](../271-[open]-catalog-body-evacuate-foundation.md) · [RFC-106](../../rfc/fixed/106-[fixed]-forja-foundation-design-system-package.md) · plan referred to issue 272 (number taken by IPTV HLS proxy fix)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **5 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I277-T01 | Slice A — search cards + filter lens painters → foundation | ✅ |
| 2 | I277-T02 | Slice B — KitSection thin mapper over CatalogSection | ✅ |
| 3 | I277-T03 | Slice C — list grid/dense/empty chrome → CatalogList composers | ✅ |
| 4 | I277-T04 | Same-turn MIGRATION.md dump rows per slice | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I277-A01 | Host search cards deleted; CatalogSearchResultCard used; filter CustomPainters in package | ✅ |
| 2 | I277-A02 | KitSection thin CatalogSection mapper; no duplicate pagination; rail API unchanged (244 lines — soft ~200 missed for TV/prefetch builders) | ✅ |
| 3 | I277-A03 | CatalogList + grid composers; inline GridView chrome gone from host list | ✅ |
| 4 | I277-A04 | Zone check + analyze clean on touched paths | ✅ |
| 5 | I277-A05 | Do not flip R106-A18 | ✅ |

---

## Summary

Issue 271 wired Zone A slots. Fat host mappers still owned search cards/lens, KitSection chrome, and list grids. Moved remaining **paint** into `forja_foundation`. MetaRuntime / Riverpod / TV stay host.

**Hard rules held:** Zone A no `package:forja/` / Riverpod / `TmdbApi` / `Movie`. Import the file, never gallery barrel. No `shared/kit/` or `shared/foundation/`. Did not flip RFC-106 A18.
