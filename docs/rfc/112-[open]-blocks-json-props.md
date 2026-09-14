# RFC-112: Blocks with JSON props (pack-callable)

**Status:** open  
**Depends on:** RFC-106, RFC-109, RFC-111  
**Area:** `packages/forja_foundation/lib/blocks/`, `PackPaintTree`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **5 / 6** acceptance · **1** ⏭️ deferred |
| **Current slice** | fromProps + PackPaintTree block mounts shipped; kit.menu/tabs/list remount deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R112-C01 | Props map readers + `fromProps` on shell/search/empty/details/catalogBody/match/entry | ✅ |
| 2 | R112-C02 | Move page shells from `widgets/` into `blocks/` | ✅ |
| 3 | R112-C03 | PackPaintTree mounts `catalogBody` / `search` / `details` / `matchDetails` / `entryDetails` / `shell` / `empty` | ✅ |
| 4 | R112-C04 | layout_map + barrels + host imports + tests + pack-author note | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R112-A01 | Packs emit data props only; callbacks injected by host painter | ✅ |
| 2 | R112-A02 | IPTV / Live Sports / My List share `catalogBody` — no product block ids | ✅ |
| 3 | R112-A03 | `MatchDetailsPage` / `EntryDetails` live under blocks with `fromProps` | ✅ |
| 4 | R112-A04 | PackPaintTree paints synthetic `catalogBody` + card child | ✅ |
| 5 | R112-A05 | Host deep imports updated; analyze clean on touched paths | ✅ |
| 6 | R112-A06 | kit.menu/tabs/list chrome remount deferred | ⏭️ |

---

## Summary

Page templates are G6 blocks. Packs call them via JSON `type` + `props` + `children`; host `PackPaintTree` mounts blocks and injects open/retry callbacks. Hub catalogs share one `catalogBody` block.

## Out of scope

Product-named catalog blocks; `SourcesPanelChrome`; remounting `kit.menu` / `kit.tabs` / `kit.list`.
