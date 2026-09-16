# Issue 279: Hub catalog design regressions after thin painter cutover

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** kit painter / hub catalog UX · [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **30 / 31** verification · A14 manual QA remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I279-A01 | Rails: landscape height + HorizontalScroller arrows + section title spacing match pre-cutover | ✅ |
| 2 | I279-A02 | `hideWhenTypeFilter` honored (Anime / Asian Drama Films·Series) | ✅ |
| 3 | I279-A03 | Continue: resume playback (not details-only) + mergeHomeWatchHistory | ✅ |
| 4 | I279-A04 | Mood: default selection + results on first paint | ✅ |
| 5 | I279-A05 | Because: shuffle control + shuffleKey | ✅ |
| 6 | I279-A06 | Hero: View details + list pin + bleed under spotlight + hideWhenBleed | ✅ |
| 7 | I279-A07 | LayoutStack: no Expanded crash in CatalogBody scroll | ✅ |
| 8 | I279-A08 | VerticalFiltersRegistry unregister on dispose | ✅ |
| 9 | I279-A09 | Hero TV interactive (gallery overlay, ShellTvFocus, bleed focus-down) | ✅ |
| 10 | I279-A10 | Rails TV row registration + pagination (KitSection parity) | ✅ |
| 11 | I279-A11 | IPTV / Live / My List product chrome: topBar→feed params, dynamic categoryBar, portals/search/refresh/view, list panel open | ✅ |
| 12 | I279-A12 | Full-page `expand` stack (bounded Column, not scroll-only) | ✅ |
| 13 | I279-A13 | Continue / mood / because TV focus graph parity | ✅ |
| 14 | I279-A14 | Manual QA: Home · Anime · Asian Drama · IPTV · Live Sports · My List look like pre-`1d9ff09b4` | ⬜ |
| 15 | I279-A15 | Composition roots (`columnsHeader` / `topBody` / `tabsCards`): live `LayoutScope` selection + `PackChromeScope.dynamicBarItems` + topBar verbs (not fold-only `onSelect`) | ✅ |
| 16 | I279-A16 | Pack chrome props honored: action icons, Live `kindIcons` mood circles, list `openSetting` (`matchOpen`), focusDown from sport circles | ✅ |
| 17 | I279-A17 | `PackLoadedPaint` loaders use finite height in CatalogBody slivers (no infinite-height crash on Home/Anime/Asian) | ✅ |
| 18 | I279-A18 | Shell `PluginKitTopBar` / `KitChromeTopBar` remounted (Search / Films / Series / Categories); scroll + hero height publish to ShellBus | ✅ |
| 19 | I279-A19 | Hero Play + bottom stadium pins; rail gaps; mood hover; anime bleed not stolen by mood; viewport-lazy rails + soft memo | ✅ |
| 20 | I279-A20 | CatalogTopChrome: segment menus + view icon group + PortalsChip slots; `walkLayoutWidgets` descends composition roots | ✅ |
| 21 | I279-A21 | Continue card play overlay + hover; home layout genre TTL shortened for rotating genre rows | ✅ |
| 22 | I279-A22 | Portals open/inventory scoped per shell tab; IPTV kind filter no longer injects Live Sports `sportFilter` | ✅ |
| 23 | I279-A23 | IPTV / Live `kit.topBar` uses restored `ForjaActionChip` + `TopBarActions` (not expanded `ForjaShellChip` strip) | ✅ |
| 31 | I279-A31 | IPTV / Live Search = expanding circle inline field (`EventListSearch`); IPTV Sort = PlayerPopupPanel Categories+Channels (not Catalog sheet) | ✅ |
| 24 | I279-A24 | Hub open shows light full-page skeleton (`homeHubLoadingSlivers`) instead of spinner | ✅ |
| 25 | I279-A25 | Hub open paints structure + section skeletons; page `feed` shared (no per-rail spinner cascade) | ✅ |
| 26 | I279-A26 | Live Sports Catalog + Schedule sheets open again (dynamic catalogs + Status×Horizon) | ✅ |
| 27 | I279-A27 | IPTV / Live catalog paint: dense list + event grid + landscape poster grid + side-rail hover (pre-wipe chrome restored in foundation) | ✅ |
| 28 | I279-A28 | Live Sports Providers fan-out restored (`LiveResolveStreams`); Live TV search maps portal hits + paint.props teams | ✅ |
| 29 | I279-A29 | IPTV / Live / hub page body fill is `bgDark` (`#141414`) like pre-wipe `CatalogShell` — not `surfaceElevated` | ✅ |
| 30 | I279-A30 | IPTV Live channel grid uses `CatalogChannelCard` (logo contain, title under mark, NOW/NEXT footer, long-press EPG sheet, hover health) — not landscape poster; Movies/Series stay posters | ✅ |

---

## Summary

Commit `1d9ff09b4` deleted `pack_layout_host_wire` (~5k) and left a stub `PackPaintTree`. Hubs still load data but **design/chrome parity was lost** across every catalog tab.

**Symptom:** empty / wrong Home, Anime, Asian Drama, IPTV, Live Sports, My List vs the previous kit host.

**Root:** thin painter mounts only posterCard/eventCard/row + partial slots; product chrome (`KitSection`, `ContinueWidget`, `kit.list`, topBar, TV focus graph, hideWhenTypeFilter) was deleted without replacement.

**A11 note:** chrome widgets mount (RFC-112 A10–A14). Product chrome behavior restored via `PackChromeScope` + `packChromeFeedParams` (selection→feed, dynamic bars, topBar verbs, Live panel).

**A15–A17:** composition mounts were still folding children and bypassing wired chrome; loaders still risked unbounded height. Host now wires PackChromeScope into composition blocks and keeps CatalogBody section loaders finite-height.

**A18–A21:** restored wiped shell `PluginKitTopBar`, hero Play + bottom pins, rail spacing + viewport lazy gate, IPTV/Live segment+view+PortalsChip chrome, anime bleed/mood pack fix, home genre layout TTL.

**A22:** portals panel open + inventory were global Riverpod — IPTV Portals toggled Live Sports too; feed also sprayed `sportFilter` on every kindMenu. Scoped per `tabId`; sport params only when list has `horizonMenu`.

**A23:** `CatalogTopChrome` was painting every menu option as plain `ForjaShellChip`s on an elevated bar. Restored pre-wipe `ForjaActionChip` + `TopBarActions` (one themed chip per action; menus open a sheet; view cycles).

**A24:** page open showed a center spinner; restored `homeHubLoadingSlivers` (+ section row shimmer in `PackLoadedPaint`).

**A25:** lazy gates showed empty boxes then N rail spinners; now section skeletons in place, first-paint/eager + shared page `feed` for claimed rails.

**A26:** Catalog/Schedule chips reopened generic flat sheets (or nothing) after wipe — restored `registerLiveScheduleChromeHooks` + Status×Horizon schedule sheet; Catalog loads live packs / Stremio options.

**A27:** IPTV/Live list paint after foundation move used stub grids — restored `CatalogCardsGrid` / `CatalogPosterGrid` / `CatalogDenseList` / `EventDenseTile` / `CatalogSideRail` (accent hover) + painter `cardKind` routing (`list`→dense, `cards`→event, `grid`+poster props→landscape posters). Packs already emit `posterCard` / `eventCard` / vertical `categoryBar`.

**A28:** Providers tab returned `[]` after `LiveResolveStreams` was deleted — restored RFC-105 fan-out under `engine/unlock/` and wired `ResolveStreamsAdapter`. Live TV game identity also reads `paint.props` teams; IPTV search hits carry `liveSourceKind` + provider label.

**A29:** composition roots (`columnsHeader` / `topBody` / side rail / hub skeleton) painted `surfaceElevated` (`#1C1C1C`) as the page fill — pre-wipe `CatalogShell` used `AppTheme.bgDark` (`#141414`). Restored `ForjaShellColors.bgDark`.

**A30:** Live IPTV cards were forced to landscape `InteractivePosterCard` (badge/subtitle NOW). Restored pre-wipe `_StreamCard` as foundation `CatalogChannelCard` + pack `channelCard` paint; host hover health via `ChannelCatalogHealthHost`.

**Must not mark fixed** until A14 QA passes on all in-scope hubs.

### Related

- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md) A69–A72 (slot paint started)
- [281](281-[open]-pack-hub-design-parity-all-hubs.md) — pack-side layout / RTL / empty parity
- [287](287-[open]-hub-structure-stable-loading.md) — follow-on: kill A24 fake page skeleton; sync layout shell + density-matched slot skeletons (no CLS)
- Baseline commit before wipe: `1d9ff09b4^` (`pack_layout_host.dart` + `pack_layout_host_wire.dart`)
