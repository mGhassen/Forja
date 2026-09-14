# RFC-112: Blocks with JSON props (pack-callable)

**Status:** open  
**Depends on:** RFC-106, RFC-109, RFC-111  
**Area:** `packages/forja_foundation/lib/blocks/`, `PackPaintTree`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **13 / 14** acceptance · **1** ⏭️ deferred |
| **Current slice** | Deleted host `kit/paint_*` section painters — packs must emit blocks |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R112-C01 | Props map readers + `fromProps` on shell/search/empty/details/catalogBody/match/entry | ✅ |
| 2 | R112-C02 | Move page shells from `widgets/` into `blocks/` | ✅ |
| 3 | R112-C03 | PackPaintTree mounts `catalogBody` / `search` / `details` / `matchDetails` / `entryDetails` / `shell` / `empty` | ✅ |
| 4 | R112-C04 | layout_map + barrels + host imports + tests + pack-author note | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R112-A01 | Packs emit data props only; callbacks injected by host painter | ✅ |
| 2 | R112-A02 | IPTV / Live Sports / My List share `catalogBody` — no product block ids | ✅ |
| 3 | R112-A03 | `MatchDetailsPage` / `EntryDetails` live under blocks with `fromProps` | ✅ |
| 4 | R112-A04 | PackPaintTree paints synthetic `catalogBody` + card child | ✅ |
| 5 | R112-A05 | Host deep imports updated; analyze clean on touched paths | ✅ |
| 6 | R112-A06 | kit.menu/tabs/list chrome remount deferred | ⏭️ |
| 7 | R112-A07 | `DetailsBlock.fromProps` / `MatchDetailsPage.fromProps` compose `DetailsHero` from props (not empty widget slots) | ✅ |
| 8 | R112-A08 | PackPaintTree remounts block types after slots refactor; unmounted topBar/categoryBar are Offstage | ✅ |
| 9 | R112-A09 | `columnsHeader` block — header + side rail + body (IPTV catalog geometry); PackPaintTree mounts it | ✅ |
| 10 | R112-A10 | `kit.topBar` / `kit.categoryBar` paint via PackTopBarSlot / PackCategoryBarSlot (LogoMenuRail) | ✅ |
| 11 | R112-A11 | `topBody` block — page top + bodyTop + grid (Live Sports geometry); PackPaintTree mounts it | ✅ |
| 12 | R112-A12 | `tabsCards` block — menu? + tabs + cards (My List geometry); PackPaintTree mounts it | ✅ |
| 13 | R112-A13 | Delete `kit/slots/`; topBar/categoryBar/menu/tabs mount foundation Catalog* chrome; host glue lives in `kit/paint_*.dart` (no Pack*Slot) | ✅ |
| 14 | R112-A14 | Delete host section painters (`paint_hero`/`mood`/`because`/`continue`/`list`/`vertical_filters`); PackPaintTree mounts blocks + chrome + CatalogCardsGrid + posterRow only | ✅ |

---

## Summary

Blocks are **prebuilt composed surfaces** with JSON props (`title`, `backdropUrl`, `overview`, …). Host injects callbacks / action rows only. Hub catalogs share `catalogBody`. Details/match blocks own `DetailsHero` paint — not empty Column shells.

## Out of scope

Product-named catalog blocks; `SourcesPanelChrome`; remounting `kit.menu` / `kit.tabs` / `kit.list`.
