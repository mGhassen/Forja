# 351 — IPTV clicks lag (await-before-paint + sync catalog FFI)

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV · channel open · Portals select · `catalog_page` · UI isolate

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I351-T01 | Live channel open: bind portal from cache; never await vault before player route | ✅ |
| 2 | I351-T02 | Portals select: optimistic row + clear grid before vault/`liveListFeedParams` | ✅ |
| 3 | I351-T03 | Yield a frame before sync `IptvCatalogDb.page` so category selection paints first | ✅ |
| 4 | I351-T04 | Root: run `iptvCatalogJson` page/has_shelf off the UI isolate (`EngineJobs` / worker) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I351-A01 | App: tap Live channel — player opens without Keychain pause | ⬜ |
| 2 | I351-A02 | App: switch portal — selected row + empty grid before vault round-trip | ⬜ |
| 3 | I351-A03 | App: flip Live categories on a large portal — UI stays fluid (no multi-frame stalls) | ⬜ |

---

## Summary

Favorite-star lag ([349](fixed/349-[fixed]-iptv-favorite-star-lag.md)) was one control. Broader “every click feels dead” comes from:

1. **Channel play** awaited `loadVaultVerifiedPortals` before `openForjaLiveNativePlayer`
2. **Portal select** awaited `setActiveKey` + `liveListFeedParams` before clearing the grid
3. **Category / search flips** rebind via pack `catalog_page` → sync Rust `iptvCatalogJson` on the **UI isolate** (`IptvCatalogDb.page` / `hasShelf`)

### Shipped this turn

- Play binds from `cachedLiveListParams['portalStoreKey']`; vault resolve is background
- Portal select paints selection + clears catalog first
- One-frame yield before sync page so rail selection can paint (symptom for T04)

### Still open (root)

T04 — move catalog SQLite/FFI off the UI isolate. Until then, large-portal category flips can still hitch after the first painted frame.

### Related

- [349](fixed/349-[fixed]-iptv-favorite-star-lag.md) — channel/portal star optimism  
- [290](290-[open]-iptv-catalog-page-host-shelf.md) — paged shelf  
- [282](282-[open]-iptv-catalog-category-rail-restore.md)
