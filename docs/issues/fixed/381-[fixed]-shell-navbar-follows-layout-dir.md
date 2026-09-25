# 381 — Shell navbar follows hub layout direction

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Shell · foundation chrome · layout `dir`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 8 / 8** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I381-T01 | Foundation `ShellNavPlacement` — rail edge, content inset, toward/away D-pad | ✅ |
| 2 | I381-T02 | Hub layout `dir` publishes to `ShellBus.hubLayoutRtlFor` | ✅ |
| 3 | I381-T03 | Shell scaffold parks rail / compact drawer / bottom-bar order from the selected tab | ✅ |
| 4 | I381-T04 | TV rail: toward-page arrow enters the page; away-page arrow stays trapped | ✅ |
| 5 | I381-T05 | Navbar follows Settings → Features **Navbar side**, not the open hub | ✅ |
| 6 | I381-T06 | Pack layout `dir` stays on that pack's page only | ✅ |
| 7 | I381-T07 | Icon scale filter paints in a local layer so a right-side rail does not flash | ✅ |
| 8 | I381-T08 | Settings hub uses the same app direction (category list on the start edge) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I381-A01 | Widget test: RTL selected hub places the rail on the right and insets the body; an LTR sibling keeps the rail on the left | ✅ |
| 2 | I381-A02 | On device, Settings → Features → Navbar side Right to left moves the navbar; Left to right puts it back. Opening an RTL hub does not move it | ⬜ |
| 3 | I381-A03 | Widget test: `shellWritingDirection` rtl parks the rail on the right; ltr keeps it on the left | ✅ |

---

## Summary

The app navbar follows **Settings → Features → Navbar side** (`Left to right` or `Right to left`). Pack layout `dir` still wraps that pack's page only. It does not move the navbar.

**Root fix:** `ShellNavPlacement` places the rail, content inset, compact drawer, and phone bar from `SettingsService.shellWritingDirection`. The value is stored in settings and loaded with the navbar.

**Related:** [RFC-070](../../rfc/070-[partial]-catalog-hub-protocol.md)
