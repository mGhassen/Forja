# RFC-085: Catalog kit is generic only

**Status:** partial  
**Depends on:** [RFC-070](070-[partial]-catalog-hub-protocol.md) · [RFC-071](fixed/071-[fixed]-live-sports-hub-kit.md) · [RFC-073](fixed/073-[fixed]-live-sports-kit-ownership.md)  
**Area:** `shared/catalog/kit/`, `features/my_list/`, `features/live_matches/`, hub packs

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 8** acceptance |
| **Current slice** | Kit primitives for pack-composed skins (`kit.topBar`, `kit.categoryBar`, list `open`) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R85-C01 | Kit holds only generic layout/chrome/cards/play — no product folders | ✅ |
| 2 | R85-C02 | `CatalogHostListRegistry` outside kit — features register opaque source ids | ✅ |
| 3 | R85-C03 | My List domain under `features/my_list/` | ✅ |
| 4 | R85-C04 | Live Sports domain under `features/live_matches/` | ✅ |

---

## Acceptance (kit evacuation slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R85-A01 | No `my_list/` or `live_schedule/` under `shared/catalog/kit/` | ✅ |
| 2 | R85-A02 | No hardcoded `CatalogKitListSources.myList` / `.liveSchedule` product switch inside kit | ✅ |
| 3 | R85-A03 | `kit.list` resolves data via host registry + optional opaque `source` / hub `pluginId` — default is not `my_list` | ✅ |
| 4 | R85-A04 | Sources-panel middleware not under a product `kit/sources/` dump folder | ✅ |
| 5 | R85-A05 | Pack layouts compose generic kit widgets; product source ids live in packs/features only | ✅ |
| 6 | R85-A06 | Host tests / imports retargeted to feature paths | ✅ |
| 7 | R85-A07 | `kit.topBar` + action chips and `kit.categoryBar` are generic kit widgets — packs compose them | ✅ |
| 8 | R85-A08 | `kit.list` `open: panel\|details` drives side panel vs generic entry details page — no product-named chrome under features | ✅ |

---

## Summary

**Rule:** `shared/catalog/kit/` is reusable UI atoms only (stack, menu, tabs, list grid, rows, cards, chrome, topBar, categoryBar, details/play helpers). Opening kit must never reveal product names (`my_list`, `live_schedule`).

**Wrong:** product chrome under `features/live_sports/` named LiveSports*TopBar / LiveSports*Details.

**Right:** packs assemble `kit.topBar` + `kit.categoryBar` + `kit.list { open: panel|details }`; features only register opaque list sources + panel data hosts.

### Related

- [RFC-073](fixed/073-[fixed]-live-sports-kit-ownership.md) — live schedule kit ownership complete
- [RFC-070](070-[partial]-catalog-hub-protocol.md) — hub protocol
