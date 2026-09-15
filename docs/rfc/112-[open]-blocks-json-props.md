# RFC-112: Blocks with JSON props (pack-callable)

**Status:** open  
**Depends on:** RFC-106, RFC-109, RFC-111  
**Area:** `packages/forja_foundation/lib/blocks/`, `PackPaintTree`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **21 / 23** acceptance · **2** ⏭️ deferred |
| **Current slice** | Pack visual props complete · atom mounts deferred |

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
| 15 | R112-A15 | One mount table (no atoms-vs-blocks fork); packs compose via `kit.stack` (or any type) of foundation components; host injects callbacks only | ✅ |
| 16 | R112-A16 | Doc: A06 remount deferral obsolete — menu/tabs/list/topBar/categoryBar mount via A10–A14; product chrome behavior → [issue 279](../issues/279-[open]-hub-catalog-design-regressions-thin-painter.md) A11 | ✅ |

---

## Acceptance (visual props slice)

Pack-overridable look on mounted catalog types. ShellTokens = Forja default when pack omits a key. Shell nav stays host-owned.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 17 | R112-A17 | Schema + host: hero `actions`/`tone`/`slideCap`/`bleedDownOffset`; rail `gap`/`rankedGap`/`pad`/`titlePad` — omit → ShellTokens | ✅ |
| 18 | R112-A18 | Home pack spotlight/featured emit current look (primary details, gap, bleedDownOffset) | ✅ |
| 19 | R112-A19 | SDK `components.md` + schema inventory of mounted/atom params (pack vs shell-forbidden) | ✅ |
| 20 | R112-A20 | mood/continue/because: `rowHeight`, `cardWidth`/`cardHeight`, `gap`, `pad`, `titlePad` — omit → defaults | ✅ |
| 21 | R112-A21 | kit.list: `gap`, `pad`, `cardKind` — omit → ShellTokens / style-derived kind | ✅ |
| 22 | R112-A22 | details / matchDetails schema + docs: `enableKenBurns`, `contentScrim`, `height`, (+ match layout keys) — Dart `fromProps` already reads | ✅ |
| 23 | R112-A23 | Mount more atoms (`Button`/`Badge`/…) as pack `type` — only when a pack needs them | ⏭️ |

---

## Summary

Blocks are **prebuilt composed surfaces** with JSON props (`title`, `backdropUrl`, `overview`, …). Host injects callbacks / action rows only. Hub catalogs share `catalogBody`. Details/match blocks own `DetailsHero` paint — not empty Column shells.

`kit.menu` / `kit.tabs` / `kit.list` / `kit.topBar` / `kit.categoryBar` **mount** in `PackPaintTree`. Remaining IPTV/Live/My List chrome fidelity (selection→feed, dynamic bars, verbs) is [issue 279](../issues/279-[open]-hub-catalog-design-regressions-thin-painter.md), not a blocks remount.

**Visual props:** hero/rail/mood/continue/because/kit.list/details/search may override look via pack JSON. Defaults remain Forja ShellTokens. Atom mounts (`Button`/`Badge`/…) stay deferred (A23) until a pack needs a new `type`.

## Out of scope

Product-named catalog blocks; `SourcesPanelChrome`. Chrome **behavior** parity is issue 279 (not this RFC). Navbar / empty-shell frame / TV focus policy — never pack-styled.