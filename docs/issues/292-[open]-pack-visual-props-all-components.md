# Issue 292: Pack-overridable visual props — all components

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** kit painter / foundation · [RFC-112](../rfc/112-[open]-blocks-json-props.md) · [291](fixed/291-[fixed]-cinematic-hero-pack-visual-props.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **31 / 33** acceptance · **2** ⏭️ deferred |
| **Current slice** | All wiring slices shipped — deferred: hero gradients, vertical_filters |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I292-T01 | Issue + README + progress matrix | ✅ |
| 2 | I292-T02 | Slice 1 — fix schema lies (because sizes, kit.row sizes, posterCard motion, eventCard tvDensity, categoryBar schema) | ✅ |
| 3 | I292-T03 | Slice 2 — poster / event / channel / EPG token pack props | ✅ |
| 4 | I292-T04 | Slice 3 — DetailsTokens pack props on details/matchDetails | ✅ |
| 5 | I292-T05 | Slice 4 — search + section/continue/because title density | ✅ |
| 6 | I292-T06 | Slice 5 — schema↔host audit, components.md, RFC-112 append | ✅ |

---

## Acceptance — done ✅ (omit → tokens)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I292-A01 | `hero` full visual surface ([291](fixed/291-[fixed]-cinematic-hero-pack-visual-props.md)) | ✅ |
| 2 | I292-A02 | `mood` rowHeight/pad/titlePad/gap | ✅ |
| 3 | I292-A03 | `continue` cardWidth/cardHeight/gap/pad/titlePad | ✅ |
| 4 | I292-A04 | `kit.list` gap/pad/cardWidth/cardKind | ✅ |
| 5 | I292-A05 | `kit.menu` / `kit.tabs` pad/padding/gap | ✅ |
| 6 | I292-A06 | `kit.topBar` height/pad/gap | ✅ |
| 7 | I292-A07 | `kit.stack` expand/axis/motion | ✅ |
| 8 | I292-A08 | `columnsHeader` / `topBody` / `tabsCards` side/bg props | ✅ |
| 9 | I292-A09 | `catalogBody` bottomGap | ✅ |
| 10 | I292-A10 | `shell` sideRailWidth/railOnLeading | ✅ |
| 11 | I292-A11 | `empty` size | ✅ |
| 12 | I292-A12 | atoms via paintFoundationType where schema lists size/spacing/color/font | ✅ |
| 13 | I292-A13 | `kit.row` gap/rankedGap/pad/titlePad/aspect | ✅ |
| 14 | I292-A14 | `because` cardWidth/cardHeight wired | ✅ |
| 15 | I292-A15 | `kit.row` itemWidth/itemHeight/height wired | ✅ |
| 16 | I292-A16 | `posterCard` motion/hoverScale/focusScale (+ borderRadius/fonts) | ✅ |
| 17 | I292-A17 | `eventCard` tvDensity + token density props | ✅ |
| 18 | I292-A18 | `kit.categoryBar` feature-rail props in schema | ✅ |
| 19 | I292-A19 | InteractivePosterCard radius/titleFont/metaFont/motion pack props | ✅ |
| 20 | I292-A20 | EventCardTokens pack props end-to-end | ✅ |
| 21 | I292-A21 | ChannelCardTokens pack props | ✅ |
| 22 | I292-A22 | EpgGuideTokens pack props | ✅ |
| 23 | I292-A23 | DetailsTokens density on details/matchDetails | ✅ |
| 24 | I292-A24 | search resultCardWidth/aspect/sectionPad (+ CatalogSearchDensity) | ✅ |
| 25 | I292-A25 | continue card title fonts pack props | ✅ |
| 26 | I292-A26 | BecauseSection title fonts pack props | ✅ |
| 27 | I292-A27 | section title fontSize on rails/continue; chips/shelf via existing atom props | ✅ |
| 28 | I292-A28 | Zero critical schema-lists-host-ignores for this matrix | ✅ |
| 29 | I292-A29 | forja-sdk components.md updated per family | ✅ |
| 30 | I292-A30 | RFC-112 append pointer (R112-A31) | ✅ |
| 31 | I292-A31 | Chassis remains shell_forbidden (no pack props) | ✅ |

---

## Acceptance — deferred ⏭️

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 32 | I292-A32 | hero private gradient alphas / homeBackdropViewportFraction | ⏭️ |
| 33 | I292-A33 | vertical_filters product rail (until restored) | ⏭️ |

---

## Summary

RFC-112 A24–A30 inventoried mounts; wiring fidelity gaps closed here (+ [291](fixed/291-[fixed]-cinematic-hero-pack-visual-props.md) for hero).

**Law:** pack optional camelCase → host parse → foundation `override ?? Token`. Chassis forbidden.

**Shipped:** schema lies fixed; poster/event/channel/EPG/details/search/continue/because density props; SDK docs; RFC-112 A31.

### Related

- [RFC-112](../rfc/112-[open]-blocks-json-props.md)
- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)
- [291](fixed/291-[fixed]-cinematic-hero-pack-visual-props.md)
- [279](279-[open]-hub-catalog-design-regressions-thin-painter.md)
