# Issue 291: Cinematic hero — pack-overridable visual props

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** kit painter / foundation catalog · [RFC-112](../../rfc/112-[open]-blocks-json-props.md) · [RFC-109](../../rfc/109-[open]-forja-pack-product-host.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **24 / 24** acceptance |
| **Current slice** | Wired — omit → ShellTokens; pack overrides on `CinematicHeroLayout` |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I291-T01 | Issue + README index | ✅ |
| 2 | I291-T02 | `CinematicHeroLayout` nullable overrides; resolve `?? ShellTokens` in hero / desktop layout / `HeroTitle` | ✅ |
| 3 | I291-T03 | `paint_tree` `_mountHero` parse pack props; wire schema ghosts `height` + `kenBurns` | ✅ |
| 4 | I291-T04 | forja-sdk schema + `docs/components.md` hero props | ✅ |
| 5 | I291-T05 | Verify omit = unchanged; pack override moves logo; flip acceptance | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I291-A01 | `heightFraction` omit → shell height fraction | ✅ |
| 2 | I291-A02 | `bleedDownOffset` omit → `homePageBottomSectionDownOffset` | ✅ |
| 3 | I291-A03 | `height` pack absolute height wired to `CinematicHero.height` | ✅ |
| 4 | I291-A04 | `kenBurns` pack overrides shell policy when set | ✅ |
| 5 | I291-A05 | `minHeight` omit → shell min height | ✅ |
| 6 | I291-A06 | `nextRowPeekFraction` omit → shell peek | ✅ |
| 7 | I291-A07 | `imageStartFraction` omit → compact/desktop image-start tokens | ✅ |
| 8 | I291-A08 | `textColumnWidth` omit → `heroTextColumnWidthDesktop` | ✅ |
| 9 | I291-A09 | `textColumnTopInset` omit → `heroTextColumnTopInsetDesktop` | ✅ |
| 10 | I291-A10 | `textColumnVerticalAlign` omit → `heroTextColumnVerticalAlign` | ✅ |
| 11 | I291-A11 | `titleSlotHeight` omit → `heroTitleSlotHeightDesktop` | ✅ |
| 12 | I291-A12 | `logoMaxHeight` omit → desktop/compact/TV logo max tokens | ✅ |
| 13 | I291-A13 | `minTitleHeight` omit → shell / metrics min title | ✅ |
| 14 | I291-A14 | `metaSlotHeight` omit → `heroMetaSlotHeightDesktop` | ✅ |
| 15 | I291-A15 | `titleMetaGap` omit → `heroTitleMetaGapDesktop` | ✅ |
| 16 | I291-A16 | `metaOverviewGap` omit → `heroMetaOverviewGapDesktop` | ✅ |
| 17 | I291-A17 | `metaActionsGap` omit → `heroMetaActionsGapDesktop` | ✅ |
| 18 | I291-A18 | `overviewMaxLines` omit → `heroOverviewMaxLinesDesktop` | ✅ |
| 19 | I291-A19 | `overviewFontSize` omit → `heroOverviewFontSizeDesktop` | ✅ |
| 20 | I291-A20 | `overviewLineHeight` omit → `heroOverviewLineHeightDesktop` | ✅ |
| 21 | I291-A21 | `upcomingNoticeReserve` omit → `heroUpcomingNoticeReserveDesktop` | ✅ |
| 22 | I291-A22 | `sectionPad` omit → `homeSectionHorizontalPadding` | ✅ |
| 23 | I291-A23 | `compactRightInset` omit → shell compact right inset | ✅ |
| 24 | I291-A24 | Chassis stays host: `tvDensity` / `compact` / `scale` / focus policy / `firstCatalogRowHeight` | ✅ |

---

## Summary

RFC-112 wired a curated hero slice (`actions`, `slideCap`, `bleedDownOffset`, `heightFraction`). Schema already listed `height` / `kenBurns` but the host ignored them. All other live cinematic-hero layout numbers stayed locked in `ShellTokens` / widget hardcodes — packs could not change logo vertical align, text inset, title slot, overview type, etc.

**Law:** pack optional camelCase props → painter parse only → foundation `override ?? ShellTokens`. Omit keeps Forja default look. Chassis/policy fields stay host-derived.

**Shipped:** `_HeroPackVisuals.fromNode` in `paint_tree.dart`; nullable fields + resolvers on `CinematicHeroLayout`; `heroDesktopTextLayout` + `HeroTitle.logoMaxHeight` accept overrides; forja-sdk schema + components.md.

Smoke: set e.g. `textColumnVerticalAlign: -0.5` on a hub `hero` node — logo/title block moves down. Hot-restart after token/package edits.

### Related

- [RFC-112](../../rfc/112-[open]-blocks-json-props.md)
- [RFC-109](../../rfc/109-[open]-forja-pack-product-host.md)
- [279](../279-[open]-hub-catalog-design-regressions-thin-painter.md)
