# Issue 287: Hub structure-stable loading (no cold-open layout shift)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** kit painter / hub catalog UX · [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 4** fix · **0 / 4** acceptance |
| **Current slice** | Sync layout shell + density-matched slot skeletons |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I287-T01 | Sync-apply EngineCache page layout; neutral wait only on cold miss (no `homeHubLoadingSlivers`) | ⬜ |
| 2 | I287-T02 | Density-aware section skeletons from pack node `type`/`title` + correct `LazyViewportGate` height | ⬜ |
| 3 | I287-T03 | Foundation density-aware poster-row skeleton helper | ⬜ |
| 4 | I287-T04 | Changelog draft bullet | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I287-A01 | Warm cache: hub open paints pack layout structure immediately (no fake hero+continue page) | ⬜ |
| 2 | I287-A02 | Cold miss: neutral wait → layout tree; rails do not jump when items fill | ⬜ |
| 3 | I287-A03 | Section skeleton padding/height matches live rails (`catalogSectionTitleTop` / card size) | ⬜ |
| 4 | I287-A04 | Manual: Home · Anime · Asian Drama · IPTV · Live Sports · Lists — no vertical chrome jump on first load | ⬜ |

---

## Summary

Cold hub open painted a host-invented full-page skeleton (`homeHubLoadingSlivers`), then remounted the pack `layout` tree, then per-rail skeletons with wrong metrics (`topPadding: 12`, undersized gate height). Structure is pack-owned (`nav.page.action` + `_layout.js`); host must paint that tree (from `EngineCache` when warm) and reserve type-matched slots while feed/rail fills.

Follow-on to [279](279-[open]-hub-catalog-design-regressions-thin-painter.md) A24/A25 — A24’s fake page skeleton becomes the anti-pattern to remove.

### Related

- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)
- [279](279-[open]-hub-catalog-design-regressions-thin-painter.md)
- [281](281-[open]-pack-hub-design-parity-all-hubs.md)
