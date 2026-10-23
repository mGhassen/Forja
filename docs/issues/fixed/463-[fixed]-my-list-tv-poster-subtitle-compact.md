# 463 — My List TV posters hide year • type (compact grid)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** My List · Android TV · poster grid  
**Reported:** 2026-10-23

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I463-T01 | Poster grid column count uses inner+gap (not `maxWidth ~/ cardW`) so stretch width stays ≥ target | ✅ |
| 2 | I463-T02 | `PosterCard` always paints subtitle when present (compact no longer drops year • type) | ✅ |
| 3 | I463-T03 | My List kit.list: slightly larger `cardWidth` + smaller `titleFontSize` (pack-only) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I463-A01 | Android TV My List Plan to Watch cards show `YYYY • TYPE` (or type alone) under the title — not title-only | ✅ |

---

## Cause

`CatalogPosterGridLayout.poster` counted columns as `maxWidth ~/ cardW`, ignoring leading/trailing pad and gaps. On leanback My List the stretch cell width fell under `PosterCard`'s compact threshold (`width < 85`), which hid the subtitle line entirely. Desktop cards stayed wide enough, so the same bookmarks looked fine there.

---

## Related

- [My List feature guide](../../features/movies-tv/my-list.md)
- [372](372-[fixed]-my-list-asian-drama-missing-year.md) — missing year in pack data (separate)
