# RFC-092: Delete root-app Live Sports — packs only

**Status:** fixed  
**Depends on:** [RFC-091](091-[fixed]-live-sports-explode-host-to-packs.md) · [RFC-087](087-[fixed]-live-sports-pack-only.md)  
**Area:** `plugins/hubs/live_sports*`, `plugins/catalog/**`, `plugins/live/**`, kit registries, `features/iptv/portal_sports/`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **8 / 8** acceptance |
| **Current slice** | **Complete** — `features/iptv/sports/` gone; hub-owned `ctx.host.liveFeed.load`; generic MetaRuntime list + resolve panel |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R92-C01 | `ctx.host.liveFeed.load` + hub feed composition | ✅ |
| 2 | R92-C02 | Generic MetaRuntime list + KitResolvePanelHost | ✅ |
| 3 | R92-C03 | Delete `features/iptv/sports/`; IPTV portal match under `portal_sports/` | ✅ |

---

## Acceptance (slice — delete sports tree)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R92-A01 | Hub `feed` calls `ctx.host.liveFeed.load` (no Dart-seeded `scheduleItems`) | ✅ |
| 2 | R92-A02 | `live_schedule` KitListSource is MetaRuntime-only (`MetaFeedListSource`) | ✅ |
| 3 | R92-A03 | Streams panel is generic `KitResolvePanelHost` (no `LiveSports*`) | ✅ |
| 4 | R92-A04 | IPTV fixture→channel match under `features/iptv/portal_sports/` | ✅ |
| 5 | R92-A05 | Schedule prefs/sheets are foundation generic (`KitSchedule*`) | ✅ |
| 6 | R92-A06 | No `apps/forja/lib/features/iptv/sports/` tree | ✅ |
| 7 | R92-A07 | No `LivePrefs` / `LiveScheduleKit` / `LiveSports*` product types | ✅ |
| 8 | R92-A08 | Boot registers via `KitLiveBoot` + `LiveSurfaceOpen` | ✅ |

---

## Summary

RFC-091 moved Live Sports out of `shared/host/` into `features/iptv/sports/` — still a product dump. This RFC deletes that tree.

**Packs** own schedule composition (`live_sports` / `live_sports_cards` `feed` → `ctx.host.liveFeed.load` → engine catalog aggregation).

**Root app** keeps only generic services: MetaRuntime list source, resolve panel, schedule prefs/sheets, engine live feed aggregate, IPTV portal sports match.
