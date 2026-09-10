# RFC-104: Merge Live Sports hubs (list/cards + panel/details)

**Status:** fixed  

**Depends on:** [RFC-087](fixed/087-[fixed]-live-sports-pack-only.md) · [RFC-085](085-[partial]-catalog-kit-generic-only.md) · [RFC-098](fixed/098-[fixed]-live-sports-event-search.md)  
**Area:** `forja-packs/hubs/live_sports/`, `shared/foundation/` kit list + schedule prefs, IPTV Portals chrome hooks

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** components · **8 / 8** acceptance |
| **Current slice** | Shipped — one hub; List/Cards top-bar; panel/details Setup; cards pack retired |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R104-C01 | `KitSchedulePrefs` list style + `kitScheduleLayoutProvider` | ✅ |
| 2 | R104-C02 | Pack `matchOpen` select + layout `openSetting`; KitList overrides | ✅ |
| 3 | R104-C03 | Top-bar List/Cards chip (left of Portals) | ✅ |
| 4 | R104-C04 | Decouple side panel from dense-list-only | ✅ |
| 5 | R104-C05 | Remove `live_sports_cards` pack + catalog row + one-shot upgrade | ✅ |

---

## Acceptance (merge slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R104-A01 | Single Live Sports hub pack (`forjahq-live-sports`); cards hub gone from forja-packs | ✅ |
| 2 | R104-A02 | Top-bar List/Cards toggle next to Portals; persists; rebuilds schedule | ✅ |
| 3 | R104-A03 | Settings → Addons → Live Sports `matchOpen`: Side panel \| Detail page | ✅ |
| 4 | R104-A04 | Panel open works with cards style; details open works with list style | ✅ |
| 5 | R104-A05 | Defaults: list + panel on first launch | ✅ |
| 6 | R104-A06 | Cards-only installs migrate once (style=cards, open=details, install list hub, remove cards pack) | ✅ |
| 7 | R104-A07 | Feature doc + changelog describe one hub | ✅ |
| 8 | R104-A08 | Supabase migration removes `live-sports-cards` catalog row (file only) | ✅ |

---

## Summary

Collapse the two Live Sports skins (`list`+`panel` vs `cards`+`details`) into one hub. Users switch list/cards from the schedule top bar and panel/details from pack Setup. Host stays pack-agnostic: style prefs gate on `live_schedule`; open mode reads `PackSettingsStore` when layout declares `openSetting`.

## Goals

1. One Features / nav tab for Live Sports.
2. Independent list↔cards and panel↔details controls.
3. Retire `forjahq-live-sports-cards` without stranding existing installs.

## Related

- [live-sports feature doc](../features/live/live-sports.md)
- [RFC-087](fixed/087-[fixed]-live-sports-pack-only.md) — pack-only Live Sports
