# 239 — Arabic hub Larozaa catalog incomplete (page 1 only + stale mirrors)

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `plugins/hubs/arabic`, `plugins/providers/larozaa`, `apps/forja/lib/shared/engine/runtime/runtime.dart`  
**Reported:** 2026-09-08

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I239-T01 | Arabic hub: honor `page` / return `hasMore` + `pageSize` on rail/search/explore (Aflem pattern) | ✅ |
| 2 | I239-T02 | Point hub + Larozaa provider bootstrap/mirrors at live `laaroza.lat` (drop broken long-chain mirrors) | ✅ |
| 3 | I239-T03 | Browse path `newvideos.php` → `newvideos1.php` | ✅ |
| 4 | I239-T04 | flutter_js `res.text()` decode `bodyB64` so large Larozaa HTML is not empty on fallback | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I239-A01 | Manual: Arabic rail / Categories / Search scroll loads page 2+ distinct titles from Larozaa | ⬜ |

---

## Summary

Arabic hub catalog only ever fetched Larozaa **page 1**, clamped to ~24 items, and never returned `hasMore`. Host infinite scroll asked for page 2+ and got the same slice again. Upstream category pages have hundreds of pages (~40 cards each). Live site also moved to `laaroza.lat`; old mirrors exceed engine `maxRedirects=8` or loop.

## Root cause

1. **`arabicLarozaList` hardcoded `page=1`** — ignored host `params.page`.
2. **No paging envelope** — `hubItems` never set `pageSize` / `hasMore` (Aflem/Brstej already did).
3. **Stale mirrors** — `laaroza.website` → 6 hops to `laaroza.lat`; `larozaa.bond` / `.com` / `.pics` chains exceed 8 redirects or infinite-loop.
4. **`newvideos.php` → `newvideos1.php`** — live browse URL renamed.
5. **flutter_js fallback** — bodies over 48 KiB ship as `bodyB64` with empty `body`; `res.text()` returned `""`, so large catalog HTML was empty on that path.

## Fix

Arabic hub matches Aflem pagination. Bootstrap prefers `https://laaroza.lat`. Provider pack mirrors updated. flutter_js `text()` / `json()` decode `bodyB64` as UTF-8.

## Verify

1. Settings → Forja Packs → Refresh Arabic (+ Providers if Larozaa streams).
2. Arabic tab → open a category rail or Categories filter → scroll past first ~24 titles → new titles appear.
3. Search a common Arabic title → scroll for more hits.
