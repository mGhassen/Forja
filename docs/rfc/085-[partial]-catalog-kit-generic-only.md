# RFC-085: Catalog kit is generic only

**Status:** partial  
**Depends on:** [RFC-070](070-[partial]-catalog-hub-protocol.md) · [RFC-071](fixed/071-[fixed]-live-sports-hub-kit.md) · [RFC-073](073-[open]-live-sports-kit-ownership.md)  
**Area:** `shared/catalog/kit/`, `features/my_list/`, `features/live_matches/`, hub packs

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **6 / 6** acceptance (this slice) |
| **Current slice** | Evacuated product trees from kit; host list registry + feature folders |

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

---

## Summary

**Rule:** `shared/catalog/kit/` is reusable UI atoms only (stack, menu, tabs, list grid, rows, cards, chrome, details/play helpers). Opening kit must never reveal product names (`my_list`, `live_schedule`).

**Wrong (RFC-071 halfway):** pack layout stubs with `source: my_list|live_schedule` and Dart backends parked under `kit/sources/`.

**Right:**

| Layer | Owns |
|-------|------|
| Kit | Generic widgets + nameless list contract |
| `CatalogHostListRegistry` (`shared/catalog/`) | Opaque source-id → feature-owned `CatalogKitListSource` |
| `features/my_list/` | Local + Simkl merge, open, pin |
| `features/live_matches/` | Schedule browse / play god-page (until RFC-073 thins it) |
| Hub packs | Layout composition; opaque `source` ids they own |

Pack-driven JS catalog rows for My List / Live schedule remain later work (RFC-073 browse). This slice is **folder honesty + registry** so kit stays generic.

### Related

- [RFC-073](073-[open]-live-sports-kit-ownership.md) — thin live schedule composition still open
- [RFC-070](070-[partial]-catalog-hub-protocol.md) — hub protocol
