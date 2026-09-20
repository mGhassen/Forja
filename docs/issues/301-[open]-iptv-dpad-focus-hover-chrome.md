# Issue 301: IPTV D-pad edges, focus restore, and hover/focus chrome

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV hub · category rail · portals panel · shell focus chrome

## Status at a glance

| | |
|--|--|
| **Progress** | **12 / 12** code · **0 / 12** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I301-T01 | Category ↓/↑: keep-visible scroll every adjacent step (no always-pin jump; no focus→index-0 scroll) | ✅ |
| 2 | I301-T02 | Channel top-row ↑ halves — left shelf / right Portals (`focusUpLeft`/`focusUpRight` + `lastItem`) | ✅ |
| 3 | I301-T03 | → last channel column → remembered portal when panel open (`focusRight: portals`) | ✅ |
| 4 | I301-T04 | Hold OK ~2s pin/reorder — `useTvFocus` + KeyUp logical activate (desktop+TV); float vs pin | ✅ |
| 5 | I301-T05 | Hub land focuses last channel (`hydrateHighlightFromStore`; longer preferCategory reset) | ✅ |
| 6 | I301-T06 | Portals chip open scrolls then focuses selected portal | ✅ |
| 7 | I301-T07 | Portal search: `TvBrowseTextField` via `searchFieldBuilder` | ✅ |
| 8 | I301-T08 | Search → at caret end → × (panel + top bar) | ✅ |
| 9 | I301-T09 | Share-code cells — `liveLeanbackOnly` + `_pasteEditing` | ✅ |
| 10 | I301-T10 | Empty Favorites/Watched — stamp empty `stream_ids` in **live** `_prelude.js` (not only dead `_platforms.js`) | ✅ |
| 11 | I301-T11 | Hover→keyboard focus + brand-green chrome | ✅ |
| 12 | I301-T12 | Pack-declared edges; category → **focus only** (never `onSelect`/reload) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I301-A01 | ATV/mac: held ↓ in category rail scrolls one row with focus | ⬜ |
| 2 | I301-A02 | ↑ from left-half top channel → shelf; right half → Portals | ⬜ |
| 3 | I301-A03 | → last channel column → selected portal (panel open); no reload | ⬜ |
| 4 | I301-A04 | Hold OK ~2s → pin; → pin; ↑/↓ reorder while floating | ⬜ |
| 5 | I301-A05 | Reopen IPTV: last category + focus/scroll last channel | ⬜ |
| 6 | I301-A06 | → from category focuses last channel (else first) — **no catalog reload** | ⬜ |
| 7 | I301-A07 | Portals chip opens scrolled to selected portal | ⬜ |
| 8 | I301-A08 | Portal search icon → field; land ≠ IME; OK types | ⬜ |
| 9 | I301-A09 | → end of query → × (panel + top bar) | ⬜ |
| 10 | I301-A10 | Share-code cells show typed letters | ⬜ |
| 11 | I301-A11 | Favorites / Already watched open their panel (empty stays empty) | ⬜ |
| 12 | I301-A12 | Hover then key → hovered control; portal row chrome while on actions | ⬜ |

---

## Summary

Rework after broken attempts: category → must **never** `onSelect` (that reloaded channels). Scroll is keep-visible per step, not always-pin. Hold-OK works on desktop hybrid + leanback. Empty Favorites fix must live in `_prelude.js` (runtime), not only `_platforms.js`. Pack **1.5.59**.

**Acceptance is still 0/12** until device QA.

## Related

- [288](288-[open]-iptv-catalog-qol-iso-v1536.md)
- [297](fixed/297-[fixed]-android-tv-iptv-vertical-panel-dpad.md)
- [123](123-[open]-android-tv-iptv-catalog-focus-after-player.md)
- [IPTV Xtream](../features/live/iptv-xtream.md)
