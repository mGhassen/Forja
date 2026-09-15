# RFC-112: Blocks with JSON props (pack-callable)

**Status:** open  
**Depends on:** RFC-106, RFC-109, RFC-111  
**Area:** `packages/forja_foundation/lib/blocks/`, `PackPaintTree`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **29 / 30** acceptance · **1** ⏭️ deferred |
| **Current slice** | Full foundation visual-props inventory mounted · A06 remount note obsolete |

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
| 23 | R112-A23 | Mount more atoms (`Button`/`Badge`/…) as pack `type` — only when a pack needs them | ✅ |

---

## Acceptance (full inventory slice)

Every foundation inventory class ends `mounted` (props wired) or `shell_forbidden`. Host: `paint_foundation_mount.dart` + PackPaintTree. Schema `statusValues` includes `shell_forbidden`.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 24 | R112-A24 | Mounted layout types: kit chrome height/pad; mood/because gap+card sizes; poster/event size keys; blocks schema catch-up; hero heightFraction; shell railOnLeading | ✅ |
| 25 | R112-A25 | Component atoms: schema type + PackPaintTree mount via `paintFoundationType` (Button…MoodCircle); Toast forbidden | ✅ |
| 26 | R112-A26 | Catalog widgets: posterRail, kenBurns, continueCard, eventDenseTile, search helpers, skeletons, … | ✅ |
| 27 | R112-A27 | Details pieces: detailsHero, playRow, pills, cast/trailers, facts, metaLine, progress, … | ✅ |
| 28 | R112-A28 | Pack-facing chrome: shellSectionTitle, shellChip, horizontalScroller, sidePanel, portals*, grids; HubTopBar/LogoMenuRail forbidden | ✅ |
| 29 | R112-A29 | Sources / guide / feedback look props: sourcesPanel, guide panels, frostedPanel, loadingDots, errorRetry, … | ✅ |
| 30 | R112-A30 | shell_forbidden audit (nav/brand/Toast/TV focus/SettingsPlayer/LayoutScope/EmptyShellFrame) + components.md + checklist | ✅ |

---

## Summary

Blocks are **prebuilt composed surfaces** with JSON props (`title`, `backdropUrl`, `overview`, …). Host injects callbacks / action rows only. Hub catalogs share `catalogBody`. Details/match blocks own `DetailsHero` paint — not empty Column shells.

`kit.menu` / `kit.tabs` / `kit.list` / `kit.topBar` / `kit.categoryBar` **mount** in `PackPaintTree`. Remaining IPTV/Live/My List chrome fidelity (selection→feed, dynamic bars, verbs) is [issue 279](../issues/279-[open]-hub-catalog-design-regressions-thin-painter.md), not a blocks remount.

**Visual props:** every pack-paintable foundation surface accepts optional JSON look props (omit → ShellTokens / Dart default). Atoms and catalog/details/chrome/sources/guide/feedback widgets mount via `paintFoundationType`. Chassis (nav rail, empty-shell frame, Toast stacking, TV focus policy, playback engines) stays `shell_forbidden`.

**Packs updated:** none (schema + host only).

### Inventory checklist (A30)

| Outcome | Count / notes |
|---------|----------------|
| **mounted + wired** | 163 schema rows with pack `type` (layout/blocks/paint + atoms/widgets via `paintFoundationType`) |
| **shell_forbidden** | 35 — Toast, FocusableTap, TmdbPaintGate, LogoMenuRail, HubTopBar, SettingsPlayerChrome, LayoutScope, ShellPaintScope, TvSearchBrowseOverlay, ListLetterJumpScope, EmptyShellFrame, ForjaLogo, AnimatedLogo, ForjaProfileAvatar, splash/TV/settings/details-pill internals, EntryDetailsChrome/DetailsScreen/DetailsPageBlock |
| **N/A** | `vertical_filters` product behavior → issue 279; playback engines / unlock internals (not DS paint) |
| **not_mounted** | **0** |

## Out of scope

Product-named catalog blocks. Chrome **behavior** parity is issue 279 (not this RFC). Navbar / empty-shell frame / TV focus policy / playback engines — never pack-styled. Sources/guide **look** props are in scope (A29); host still owns panel orchestration.