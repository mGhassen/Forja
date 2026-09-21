# Issue 313: Android TV Live Sports Side panel opens detail page

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Live Sports · `matchOpen` · kit list side panel

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I313-T01 | `kitListCanShowSidePanel` — Android TV docks even when layout width &lt; side-panel breakpoint (align with `SidePanelOverlay`) | ✅ |
| 2 | I313-T02 | Unit tests: narrow ATV + chrome → can show panel; narrow desktop → cannot | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I313-A01 | Unit: ATV + chrome + narrow width → panel path | ✅ |
| 2 | I313-A02 | Android TV: Open matches in → Side panel → OK on a match opens Providers beside the schedule (not the detail page) | ⬜ |

---

## Summary

**Symptom:** On Android TV, with Live Sports **Setup → Open matches in → Side panel**, OK / click on a match still opened the full **detail page**.

**Root cause:** Issue 304 gated the panel on `chrome != null && constraints.maxWidth >= 900`. Leanback logical widths (and the list strip after Portals docks) often sit under 900px, so panel preference fell through to details. `SidePanelOverlay` already treated Android TV as always-docked; kit list open did not.

**Root fix:** Shared `kitListCanShowSidePanel` — Android TV always allows the docked panel when chrome is present; desktop still uses the wide breakpoint for phone/narrow fallback to details.

### Related

- [304](fixed/304-[fixed]-live-sports-match-tap-open.md) — match tap panel / details resolver
- Feature: [live-sports](../../features/live/live-sports.md)
