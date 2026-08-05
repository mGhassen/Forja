# 147 — Android TV Portals panel steals D-pad focus back to the active portal

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV Portals panel · Android TV D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I147-T01 | Mark the panel-open header handoff as consumed in `initState` so a later notify cannot re-run it | ✅ |
| 2 | I147-T02 | `_focusPanelHeader` bails when focus is already inside the panel | ✅ |
| 3 | I147-T03 | Skip active-portal / new-portal scroll while a portal row holds focus; compare active index against the filtered list | ✅ |
| 4 | I147-T04 | ↓ from header returns to the last row reached with ↑/↓ (active portal only on first entry); reset on search change / panel close | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I147-A01 | Android TV: open Portals, hold ↓ through the list — focus never jumps to the header or back to the playing portal | ⬜ |
| 2 | I147-A02 | Dwell >2s on a row (status probe runs) — focus and scroll position stay put | ⬜ |
| 3 | I147-A03 | ↑ from a row to the header, then ↓ — focus returns to that row, not the playing portal | ⬜ |

---

## Summary

On Android TV, scrolling the Portals panel with the D-pad threw focus back to the playing portal one or two seconds after opening the panel.

**Root cause:** `_IptvPortalPanelState.initState` scheduled the open-time `_focusPanelHeader()` but never set `_didFocusHeaderOnOpen`. The flag was only set inside `_onCtrlChanged`, so the **first** `notifyListeners()` after the panel opened re-focused the header **Add (+)** button — and the panel guarantees one: focusing a row schedules a 2s portal health probe (`schedulePortalHealthCheck`), which notifies on start, on merge, and on completion. The user's next ↓ then ran `_focusPortalsFromHeader`, which always targeted `iptvActivePortalFocusIndex` — the playing portal.

**Root fix:** the open handoff is consumed in `initState`, `_focusPanelHeader` refuses to take focus that is already inside the panel, scroll-to-active/new-portal is skipped while a portal row is focused, and header ↓ restores the row the user left.

## Related

- `apps/forja/lib/features/iptv/iptv/screens/iptv_catalog_portal_panel.dart`
- `iptvRowHasFocus` — `apps/forja/lib/features/iptv/iptv/iptv_tv_focus.dart`
- [144](144-[open]-iptv-catalog-stream-health-never-reprobes.md) — health TTL that drives the notify storm
- [iptv-xtream](../features/live/iptv-xtream.md) — Portals panel D-pad map
