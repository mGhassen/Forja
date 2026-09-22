# Issue 301: IPTV D-pad edges, focus restore, and hover/focus chrome

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV hub · category rail · portals panel · shell focus chrome

## Status at a glance

| | |
|--|--|
| **Progress** | **13 / 13** code · **0 / 12** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I301-T01 | Category ↓/↑: keep-visible scroll every adjacent step (no always-pin jump; no focus→index-0 scroll) | ✅ |
| 2 | I301-T02 | Channel top-row ↑ halves — **viewport** left shelf / right Portals (`focusUpLeft`/`focusUpRight` + spatial half) | ✅ |
| 3 | I301-T03 | → last channel column → remembered portal when panel open (`focusRight: portals`) | ✅ |
| 4 | I301-T04 | Hold OK ~2s pin/reorder — clear pin on blur; single chrome owner (no dual green) | ✅ |
| 5 | I301-T05 | Hub land focuses last **category**; scrolls last channel into view (`hydrateHighlightFromStore` keeps `preferCategoryFocusOnLand`) | ✅ |
| 6 | I301-T06 | Portals chip open scrolls then focuses selected portal | ✅ |
| 7 | I301-T07 | Portal search: `TvBrowseTextField` via `searchFieldBuilder` | ✅ |
| 8 | I301-T08 | Search → at caret end → × (panel + top bar) | ✅ |
| 9 | I301-T09 | Share-code cells — `liveLeanbackOnly` + `_pasteEditing` | ✅ |
| 10 | I301-T10 | Empty Favorites/Watched — stamp empty `stream_ids` in **live** `_prelude.js` | ✅ |
| 11 | I301-T11 | Hover→keyboard focus via shared `ShellHoverFocus` (nav + top bar + settings + lists) | ✅ |
| 12 | I301-T12 | Category → focuses **in-front** channel (spatial); search OK → first hit or keep field | ✅ |
| 13 | I301-T13 | Pack `focus.enter/restore: cats` + arm cats memory on select (nav OK lands last selected category) | ✅ |

---

## Acceptance (device QA — user list)

| # | What | Status |
|--:|------|--------|
| 1 | Category ↓ scrolls with focus | ✅ (user) |
| 2 | ↑ top channels: left half → shelf, right → Portals | ⬜ retest |
| 3 | Hold OK pin / no dual green / no jump to selected | ⬜ retest |
| 4 | Category → in-front channel | ⬜ retest |
| 5 | Open hub → last category focused; channel scrolled | ⬜ retest |
| 6 | Back from player → channel (not category) | ⬜ retest |
| 7 | → last channel → selected portal | ✅ (user) |
| 8 | Hover→key top bar / nav / settings | ⬜ retest |
| 9 | Portal row chrome on actions | ✅ (user) |
| 10 | Portals chip scrolls to selected | ✅ (user) |
| 11 | Share-code cells show typed letters | — see note |
| 12 | Search OK → first channel or keep search | ⬜ retest |
| 13 | Search → × at end | ✅ (user) |
| 14–18 | Green chrome; Portals chip green **only** hover/focus | ⬜ retest chip |
| 19 | Favorites / Watched panel | ⬜ retest |

**#11 (share-code):** the nine cells in **Add portal → paste share code**. Typing should paint each letter in its box (not a blank row). That path uses browse-until-OK on leanback only.

**Acceptance remains open** until device retest after hot restart + pack **1.5.60+**.

## Related

- [288](288-[open]-iptv-catalog-qol-iso-v1536.md)
- [297](fixed/297-[fixed]-android-tv-iptv-vertical-panel-dpad.md)
- [123](123-[open]-android-tv-iptv-catalog-focus-after-player.md)
- [IPTV Xtream](../features/live/iptv-xtream.md)
