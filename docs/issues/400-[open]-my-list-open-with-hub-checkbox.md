# 400 — My List Open with… does not save a different hub

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** My List · Open with · RFC-108  
**Reported:** 2026-10-01

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I400-T01 | Open with… searches every hub; check a title to save that hub (nothing pre-checked) | ✅ |
| 2 | I400-T02 | A non-TMDB match stores that hub’s media type on the bookmark | ✅ |
| 3 | I400-T03 | Checking a title saves the hub and stays on the sheet | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I400-A01 | Right-click a My List title, pick Asian Drama, check the title — next open uses that hub | ⬜ |

---

## Cause

Open with… treated a compatible hub (usually Home) as already chosen: a checked **Open in Home** row, no search, no title to select. Switching the hub chip did not save until that direct row was confirmed, and Asian Drama never offered the same search-and-check as the other hubs.

## Fix

- Right-click / long-press **Open with…** searches the selected hub, including Home.
- Each match has a checkbox. Checking it saves that hub and opens the title.
- First-open **Open in…** still uses the direct row when the bookmark already matches one hub.

## Related

- [RFC-108](../rfc/fixed/108-[fixed]-my-list-open-hub-binding.md)
- [My List](../features/movies-tv/my-list.md)
