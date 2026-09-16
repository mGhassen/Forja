# Issue 288: IPTV catalog QoL ISO with v1.5.36

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** IPTV hub · pack kit catalog · player return

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** fix · **0 / 10** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I288-T01 | Persist + land last Live category / channel (`PortalLiveChannelListsStore` callers) | ✅ |
| 2 | I288-T02 | After player: scroll + focus/highlight playing channel; wire `onChannelChanged` | ✅ |
| 3 | I288-T03 | Register TV grid row `'items'`; fix `liveFocusBrowserStreamAt` row id | ✅ |
| 4 | I288-T04 | Fav/Watched hold OK ~1s → jump to real category (no play) | ✅ |
| 5 | I288-T05 | Live compact list rows when width &lt; 720 | ✅ |
| 6 | I288-T06 | Catalog lazy logos (500ms idle settle, leanback) | ✅ |
| 7 | I288-T07 | Instant jumpTo scroll helpers on channel grid + category rail | ✅ |
| 8 | I288-T08 | Category rail `tvRowId: 'cats'` + tabId for focus graph | ✅ |
| 9 | I288-T09 | Changelog + feature doc glance | ✅ |
| 10 | I288-T10 | Letter-jump hover `requestFocus` ISO with v1.5.36 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I288-A01 | Reopen IPTV: last Live category selected; last-played channel scrolled/highlighted (no autoplay) | ⬜ |
| 2 | I288-A02 | Leave player: D-pad/focus lands on playing channel (incl. guide zap); desktop keeps highlight | ⬜ |
| 3 | I288-A03 | Favorites/Watched: hold OK ~1s jumps to portal group without playing | ⬜ |
| 4 | I288-A04 | Phone width &lt;720: Live channels are list rows, not grid | ⬜ |
| 5 | I288-A05 | Leanback: logos appear after 500ms idle; no thrash while skimming categories | ⬜ |
| 6 | I288-A06 | Letter-jump / restore: channel scrolls into view via jumpTo / ensureVisible | ⬜ |
| 7 | I288-A07 | Category rail D-pad row id is `cats`; channel grid is `items` | ⬜ |
| 8 | I288-A08 | Sunrise hold + TV skim-OK commit already on `CatalogCategoryRail` — still work | ⬜ |
| 9 | I288-A09 | Manual: desktop hover health/play overlay still fluid after player | ⬜ |
| 10 | I288-A10 | Letter-jump hover requestFocus matches v1.5.36 (type-to-jump while pointer over list) | ⬜ |

---

## Summary

Pack cutover left store APIs and TV focus helpers **dead** (zero callers / wrong row id `'browser-streams'` vs layout `'items'`). User-visible QoL from **v1.5.36** (`features/iptv`) rewired into pack host + foundation without resurrecting the god screen.

**Shipped in host/foundation:**

- `IptvCatalogLand` — last cat/channel persist, highlight, post-player restore, visible-filter check
- Category rail loads/saves last Live category; `tvRowId: cats`
- Channel grid `tvRowId: items`; land scroll/focus via `landEpoch`
- Fav/Watched hold OK → real portal group
- Compact list &lt;720; leanback 500ms lazy logos; `jumpTo` scroll helpers
- `onChannelChanged` remembers zap’d channel for after-player land
- Letter-jump hover `requestFocus` restored (ISO with v1.5.36)

**Already present (not reimplemented):** category rail sunrise hold, TV skim vs OK commit, pin/reorder, Favorites/Watched lists, letter-jump matcher, Portals panel/chip, Cards/EPG, player guide.

### Related

- [123](123-[open]-android-tv-iptv-catalog-focus-after-player.md) — ATV after-player focus (pre-wipe fix; needs rewire)
- [282](282-[open]-iptv-catalog-category-rail-restore.md) — category rail restore
- [279](279-[open]-hub-catalog-design-regressions-thin-painter.md) — thin painter
- Recover: `git show v1.5.36:apps/forja/lib/features/iptv/screens/iptv_pt_browser_view.dart`
