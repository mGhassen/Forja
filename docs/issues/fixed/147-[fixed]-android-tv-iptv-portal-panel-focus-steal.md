# 147 — Android TV Portals panel steals D-pad focus back to the active portal

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV Portals panel · Android TV D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** fix · **0 / 6** acceptance |

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
| 8 | I147-T08 | Desktop pointer/trackpad scroll: set browsing flag; skip auto scroll-to-active and stale focus restore until D-pad `_focusPortalAt` | ✅ |
| 9 | I147-T09 | Re-wire into pack-product Portals panel (`PortalListView` + host `PortalsPanelTvFocus`) after `portals_ui` removal | ✅ |
| 10 | I147-T10 | Desktop mouse hover/delete: mark pointer browse + gate row fill on `focusStyled` so inventory rebuild after delete does not show focus chrome | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I147-A01 | Android TV: open Portals, hold ↓ through the list — focus never jumps to the header or back to the playing portal | ⬜ |
| 2 | I147-A02 | Dwell >2s on a row (status probe runs) — focus and scroll position stay put | ⬜ |
| 3 | I147-A03 | ↑ from a row to the header, then ↓ — focus returns to that row, not the playing portal | ⬜ |
| 4 | I147-A04 | Hold ↓ through the Portals list — only the focused row shows a green fill; no desktop hover star/rail on rows you skim past | ⬜ |
| 5 | I147-A05 | Desktop: open Portals, scroll with mouse/trackpad — list does not jump back to the top / playing portal when status probes notify | ⬜ |
| 6 | I147-A06 | Desktop: delete a portal with the mouse — no focus fill/chrome appears on another row after the list refreshes | ⬜ |

---

## Summary

On Android TV, scrolling the Portals panel with the D-pad threw focus back to the playing portal one or two seconds after opening the panel.

**Root cause:** `_IptvPortalPanelState.initState` scheduled the open-time `_focusPanelHeader()` but never set `_didFocusHeaderOnOpen`. The flag was only set inside `_onCtrlChanged`, so the **first** `notifyListeners()` after the panel opened re-focused the header **Add (+)** button — and the panel guarantees one: focusing a row schedules a 2s portal health probe (`schedulePortalHealthCheck`), which notifies on start, on merge, and on completion. The user's next ↓ then ran `_focusPortalsFromHeader`, which always targeted `iptvActivePortalFocusIndex` — the playing portal.

**Root fix (classic panel):** the open handoff is consumed in `initState`, `_focusPanelHeader` refuses to take focus that is already inside the panel, scroll-to-active/new-portal is skipped while a portal row is focused, and header ↓ restores the row the user left.

**Pack-product re-wire (I147-T09):** after `portals_ui` deletion, the same graph lives in foundation `PortalListView` / `PortalListRow` (`ShellPaintScope` taps + vertical `portals` row) and host `PortalsPanelTvFocus` + `PortalsPanelView` (`ShellTvContainDpad`, jump-then-focus, no-steal on health rebuild, ← header, → action rail).

## Related

- `packages/forja_foundation/lib/widgets/chrome/portal_list_*.dart`
- `apps/forja/lib/shared/engine/runtime/actions/portals/portals_panel_tv.dart`
- [144](../144-[open]-iptv-catalog-stream-health-never-reprobes.md) — health TTL that drives the notify storm
