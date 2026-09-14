# Issue 279: Hub catalog design regressions after thin painter cutover

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** kit painter / hub catalog UX · [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **16 / 17** verification · A14 manual QA remaining |

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

---

## Summary

Commit `1d9ff09b4` deleted `pack_layout_host_wire` (~5k) and left a stub `PackPaintTree`. Hubs still load data but **design/chrome parity was lost** across every catalog tab.

**Symptom:** empty / wrong Home, Anime, Asian Drama, IPTV, Live Sports, My List vs the previous kit host.

**Root:** thin painter mounts only posterCard/eventCard/row + partial slots; product chrome (`KitSection`, `ContinueWidget`, `kit.list`, topBar, TV focus graph, hideWhenTypeFilter) was deleted without replacement.

**A11 note:** chrome widgets mount (RFC-112 A10–A14). Product chrome behavior restored via `PackChromeScope` + `packChromeFeedParams` (selection→feed, dynamic bars, topBar verbs, Live panel).

**A15–A17:** composition mounts were still folding children and bypassing wired chrome; loaders still risked unbounded height. Host now wires PackChromeScope into composition blocks and keeps CatalogBody section loaders finite-height.

**Must not mark fixed** until A14 QA passes on all in-scope hubs.

### Related

- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md) A69–A72 (slot paint started)
- [281](281-[open]-pack-hub-design-parity-all-hubs.md) — pack-side layout / RTL / empty parity
- Baseline commit before wipe: `1d9ff09b4^` (`pack_layout_host.dart` + `pack_layout_host_wire.dart`)
