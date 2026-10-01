# 297 — Android TV IPTV vertical panels: ↑/↓ in-panel, ←/→ between panels

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Android TV · IPTV catalog · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **1 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I297-T01 | Pack: drop cats↓items / items↑cats D-line; cats→items via focusRight | ✅ |
| 2 | I297-T02 | Category rail: scroll-into-view + → enters channels; cats onFocusDown trap | ✅ |
| 3 | I297-T03 | Coordinator: jump-then-focus adjacent; trap vertical / grid first-last edges | ✅ |
| 4 | I297-T04 | Portals last ↓ trap; matrix test; changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I297-A01 | Android TV IPTV: ↑/↓ in category rail scrolls categories only | ⬜ |
| 2 | I297-A02 | → from category enters channel grid; ← from first channel column returns to cats | ⬜ |
| 3 | I297-A03 | Channel grid ↑/↓ stays in channels (no hop to cats); Portals last ↓ stays in Portals | ⬜ |
| 4 | I297-A04 | Widget: cats↓ stays on cats; last cat ↓ traps (`dpad_matrix_coverage_test`) | ✅ |

---

## Summary

Pack cutover wired **cats↓→items** and vertical rows fell through to spatial focus when the next lazy tile was unmounted — ↓ left the category list instead of scrolling it. Classic IPTV treated categories, channels, and Portals as **independent vertical panels**: ↑/↓ only inside the panel; ←/→ between panels.

**Root fix:** Restore panel graph — jump-then-focus within a vertical row, trap at ends (no sortOrder D-line), pack `focusRight: items` for cats→channels, trap Portals last ↓.

### Related

- [136](../136-[open]-android-tv-iptv-catalog-guide-scroll-focus.md) — catalog scroll chrome
- [288](../288-[open]-iptv-catalog-qol-iso-v1536.md) — catalog QoL ISO
