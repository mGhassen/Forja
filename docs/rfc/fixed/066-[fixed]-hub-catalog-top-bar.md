# RFC-066: Anime & Asian Drama hub catalog top bar

**Status:** fixed  
**Area:** `apps/forja/lib/shell/`, `features/anime/`, `features/asian_drama/`  
**Depends on:** RFC-025 (HomeTopBar chrome)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** components · **8 / 8** acceptance |
| **Current slice** | Films · Series · Categories + Search shipped on Anime / Asian Drama |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R66-C01 | Shared `CatalogTopBar` chrome (tabs, categories menu, search, scroll-hide, TV focus) | ✅ |
| 2 | R66-C02 | ShellBus + hero/scroll publish for Anime / Asian Drama | ✅ |
| 3 | R66-C03 | Anime hub: Films / Series / genre Categories filter + top bar | ✅ |
| 4 | R66-C04 | Asian Drama hub: Films / Series / country Categories filter + top bar | ✅ |

---

## Acceptance (hubs)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R66-A01 | Anime + Asian Drama show Home-style top bar (Films · Series · Categories ▾ · Search) on desktop/TV | ✅ |
| 2 | R66-A02 | Search moves into top bar; hero corner search removed | ✅ |
| 3 | R66-A03 | Anime Films = `MOVIE`; Series = non-movie formats; Categories = AniList genres (in-place) | ✅ |
| 4 | R66-A04 | Asian Drama Films = `Movie`; Series = `TVSeries`; Categories = KissKH country (explore when set) | ✅ |
| 5 | R66-A05 | Tap active Films/Series again clears media filter (mixed); Categories All clears genre/country | ✅ |
| 6 | R66-A06 | Top bar scroll-hides with hub hero like Home | ✅ |
| 7 | R66-A07 | TV: top-bar row in focus graph; DOWN → hero gallery | ✅ |
| 8 | R66-A08 | Continue watching stays unfiltered | ✅ |

---

## Summary

Mirror Home’s catalog top menu on Anime and Asian Drama: **Films · Series · Categories** + Search overlay on the hub hero. Filters apply in-place to hub rails/hero (not Discover/Explore destinations).

### Contracts

| Hub | Films | Series | Categories |
|-----|-------|--------|------------|
| Anime | AniList `MOVIE` | TV / TV_SHORT / OVA / ONA / SPECIAL / … | AniList genre labels |
| Asian Drama | KissKH `Movie` | `TVSeries` | Country via explore when selected; type filter client-side on home rails |

Home keeps **TV Shows** label; hubs use **Series**.
