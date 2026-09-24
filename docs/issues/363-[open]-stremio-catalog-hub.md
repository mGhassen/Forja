# 363 — Stremio catalog hub (empty shell + addon catalogs)

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja` host bridge · `forja-packs/hubs/stremio`

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** fix · **0 / 5** acceptance |
| **Current slice** | Code shipped — manual QA pending |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I363-T01 | `HostEngineRequest` kind `stremio` (`list` / `catalog` / `search`) | ✅ |
| 2 | I363-T02 | `needsStremioCatalogHost` + flutter_js for `layout` / `rail` / `search` | ✅ |
| 3 | I363-T03 | Pack `hubs/stremio` — empty shell; rails 1:1 from addon catalogs | ✅ |
| 4 | I363-T04 | Tighten `loadKitStremioDetails` `/meta` field map (no TMDB) | ✅ |
| 5 | I363-T05 | Tests + changelog + feature guide | ✅ |
| 6 | I363-T06 | Allow empty `widgets: []` in `validateLayoutData` (empty shell) | ✅ |
| 7 | I363-T07 | Stremio details meta/episodes + green Play via Stremio streams | ✅ |
| 8 | I363-T08 | Paint rail/hero items (`hubItems` + host type fix) so details get movie/TV + open | ✅ |
| 9 | I363-T09 | Sources Forja uses movie/tv panel (not empty stremio bucket); open on Stremio tab | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I363-A01 | Hub alone, no VOD catalog addons → empty page (no preset rails) | ⬜ |
| 2 | I363-A02 | Install Cinemeta (`vod`) → only that addon's `catalogs[]` as rails | ⬜ |
| 3 | I363-A03 | Second catalog addon appends rails; remove → those rails gone | ⬜ |
| 4 | I363-A04 | Open title → Stremio `/meta` details → Sources (no TMDB details) | ⬜ |
| 5 | I363-A05 | Pack has no fixed rail ids / no TMDB URLs / no `open.surface: tmdb` | ⬜ |

---

## Summary

Stremio Board-style hub: empty shell until VOD catalog addons are installed. Pack maps `getAllCatalogs` → rail widgets only — no Home-style preset rows, no TMDB. Details reuse `loadKitStremioDetails`.

### Related

- [RFC-050](../rfc/050-[open]-stremio-addon-feature-targets.md)
- [RFC-070](../rfc/070-[partial]-catalog-hub-protocol.md)
- [stremio-addons](../features/sources/stremio-addons.md)
- [feature guide](../features/hubs/stremio-catalog.md)
