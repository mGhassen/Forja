# Issue 282: Restore IPTV catalog category rail (pack widget + host engines)

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV hub · kit categoryBar · [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 8** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I282-T01 | Foundation `CatalogCategoryRail` (pin / DnD / hover / TV hold) | ✅ |
| 2 | I282-T02 | Host `CategoryBarActionHost` + `PortalLiveChannelListsStore` SoT | ✅ |
| 3 | I282-T03 | Painter routes `kit.categoryBar` features → rich rail | ✅ |
| 4 | I282-T04 | IPTV pack: features props + `__favorites__` / `__watched__` kinds + feed filter | ✅ |
| 5 | I282-T05 | Channel favorite star + record watched on live play | ✅ |
| 6 | I282-T06 | SDK / feature doc / changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I282-A01 | Live category rail shows Favorites + Already watched (always, even empty) | ⬜ |
| 2 | I282-A02 | Desktop: hover green rail + pin on hover; pin toggles and reorders under widgets | ⬜ |
| 3 | I282-A03 | Desktop: delayed drag reorders movable categories (playlist sort, no search) | ⬜ |
| 4 | I282-A04 | TV: hold OK reveals pin / floating reorder; Back exits chrome | ⬜ |
| 5 | I282-A05 | Selecting Favorites / Already watched filters channels from host store lists | ⬜ |
| 6 | I282-A06 | Channel star toggles favorites; live play records Already watched (max 30) | ⬜ |
| 7 | I282-A07 | Pack invokes via `kit.categoryBar` features; Movies/Series stay plain rail | ⬜ |
| 8 | I282-A08 | SoT is `PortalLiveChannelListsStore` (`pt_iptv_live_*`) — not pack vault prefs | ⬜ |

---

## Summary

Pre-wipe Live IPTV sidebar (`_CategorySidebarRow`: pin, drag-reorder, hover, Favorites / Already watched) was deleted with `features/iptv` (`121f0779c`). Thin painter mounts plain `CatalogSideRail` (select + hover only). Store APIs (`PortalLiveCatalog` / `PortalLiveChannelListsStore`) still exist with zero callers.

**Shipped:** pack emits `kit.categoryBar` with `features`; foundation paints `CatalogCategoryRail`; host `CategoryBarActionHost` owns pin/fav/watched/order engines (mirror `PortalsActionHost`).

### Related

- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)
- [279](279-[open]-hub-catalog-design-regressions-thin-painter.md) — thin painter cutover
- Recover: `git show 96895defd:apps/forja/lib/features/iptv/screens/iptv_pt_browser_sidebar.dart`
