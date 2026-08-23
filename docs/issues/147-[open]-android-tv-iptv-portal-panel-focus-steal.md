# 147 — Android TV Portals panel steals D-pad focus back to the active portal

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV Portals panel · Android TV D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I147-T01 | Mark the panel-open header handoff as consumed in `initState` so a later notify cannot re-run it | ✅ |
| 2 | I147-T02 | `_focusPanelHeader` bails when focus is already inside the panel | ✅ |
| 3 | I147-T03 | Skip active-portal / new-portal scroll while a portal row holds focus; compare active index against the filtered list | ✅ |
| 4 | I147-T04 | ↓ from header returns to the last row reached with ↑/↓ (active portal only on first entry); reset on search change / panel close | ✅ |
| 5 | I147-T05 | TV ↑/↓: no MouseRegion hover, sync-clear focus chrome, green fill only on the focused row, jump-then-focus (no `.item` ensureVisible) | ✅ |
| 6 | I147-T06 | ↓ from header retries while scrape list is still empty (first portal mounting) | ✅ |
| 7 | I147-T07 | Scrape/health notify: skip scroll + restore list focus when `_lastFocusedPortalIndex` set (rebuild focus flicker) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I147-A01 | Android TV: open Portals, hold ↓ through the list — focus never jumps to the header or back to the playing portal | ⬜ |
| 2 | I147-A02 | Dwell >2s on a row (status probe runs) — focus and scroll position stay put | ⬜ |
| 3 | I147-A03 | ↑ from a row to the header, then ↓ — focus returns to that row, not the playing portal | ⬜ |
| 4 | I147-A04 | Hold ↓ through the Portals list — only the focused row shows a green fill; no desktop hover star/rail on rows you skim past | ⬜ |

---

## Summary

On Android TV, scrolling the Portals panel with the D-pad threw focus back to the playing portal one or two seconds after opening the panel.

**Root cause:** `_IptvPortalPanelState.initState` scheduled the open-time `_focusPanelHeader()` but never set `_didFocusHeaderOnOpen`. The flag was only set inside `_onCtrlChanged`, so the **first** `notifyListeners()` after the panel opened re-focused the header **Add (+)** button — and the panel guarantees one: focusing a row schedules a 2s portal health probe (`schedulePortalHealthCheck`), which notifies on start, on merge, and on completion. The user's next ↓ then ran `_focusPortalsFromHeader`, which always targeted `iptvActivePortalFocusIndex` — the playing portal.

**Root fix:** the open handoff is consumed in `initState`, `_focusPanelHeader` refuses to take focus that is already inside the panel, scroll-to-active/new-portal is skipped while a portal row is focused, and header ↓ restores the row the user left.

**Follow-up (I147-T05):** D-pad ↑/↓ through the list still painted desktop hover (white fill + star, often on two rows for a frame). Same treatment as category rail [I136-T15](136-[open]-android-tv-iptv-catalog-guide-scroll-focus.md): no `MouseRegion` on TV, sync-clear `_focused`, one brand-green fill, list jump owns scroll (`ensureVisible` off). NEW chrome clears on OK, not on skim.

## Related

- `apps/forja/lib/features/iptv/iptv/screens/iptv_catalog_portal_panel.dart`
- `iptvRowHasFocus` — `apps/forja/lib/features/iptv/iptv/iptv_tv_focus.dart`
- [144](144-[open]-iptv-catalog-stream-health-never-reprobes.md) — health TTL that drives the notify storm
- [iptv-xtream](../features/live/iptv-xtream.md) — Portals panel D-pad map
