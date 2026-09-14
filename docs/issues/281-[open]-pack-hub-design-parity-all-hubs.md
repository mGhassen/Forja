# Issue 281: Pack hub design parity (all hubs)

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** forja-packs hubs · pack layout / RTL / load / empty · [RFC-109](../rfc/109-[open]-forja-pack-product-host.md) · [279](279-[open]-hub-catalog-design-regressions-thin-painter.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **13 / 14** pack parity · A14 manual QA remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I281-A01 | IPTV layout root → `columnsHeader`; Portals Deal action; no-portal `empty` | ✅ |
| 2 | I281-A02 | Live Sports layout root → `topBody`; empty schedule `empty` | ✅ |
| 3 | I281-A03 | My List layout root → `tabsCards`; empty status `empty` | ✅ |
| 4 | I281-A04 | Home: `"feed"` in manifest capabilities | ✅ |
| 5 | I281-A05 | Anime: `feed: true` on layout page for first-paint consistency | ✅ |
| 6 | I281-A06 | Asian Drama feature doc: Popular = KissKH most_viewed (not TMDB) | ✅ |
| 7 | I281-A07 | Arabic: `dir: rtl` + hero `hubWithLoad` | ✅ |
| 8 | I281-A08 | Aflem: `dir: rtl` + `hubWithLoad` on hero + ranked series | ✅ |
| 9 | I281-A09 | Cartoon: `dir: rtl` + `hubWithLoad` on hero + popular ranked | ✅ |
| 10 | I281-A10 | Kids: `dir: rtl` + `hubWithLoad` on hero | ✅ |
| 11 | I281-A11 | Shahid: `hubWithLoad` on hero/rails; filters → peer menus/fields; signed-out `empty` | ✅ |
| 12 | I281-A12 | Cross-hub: empty widgets where docs promise empty copy | ✅ |
| 13 | I281-A13 | Pack versions bumped for every changed hub | ✅ |
| 14 | I281-A14 | Manual QA: arabic family + chrome hubs match feature docs | ⬜ |

---

## Summary

Host issue [279](279-[open]-hub-catalog-design-regressions-thin-painter.md) remounts painter chrome/TV. This issue tracks **pack-side** design parity for every hub: composition roots (IPTV / Live / My List), RTL + `hubWithLoad` (arabic family), capabilities/docs nits (home / anime / asian), and `empty` rows.

**Non-goals:** invent mood / because / TMDB enrich on hubs that never had them.

### Related

- [279](279-[open]-hub-catalog-design-regressions-thin-painter.md) — host painter chrome + TV
- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)
- [RFC-112](../rfc/112-[open]-blocks-json-props.md) — composition blocks (`columnsHeader` / `topBody` / `tabsCards`)
