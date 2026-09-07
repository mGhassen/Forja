# RFC-091: Explode Live Sports host — packs own MetaRuntime

**Status:** fixed  
**Depends on:** [RFC-087](087-[fixed]-live-sports-pack-only.md) · [RFC-090](090-[fixed]-live-sports-host-outside-foundation.md) · [RFC-085](../085-[partial]-catalog-kit-generic-only.md)  
**Area:** `plugins/hubs/live_sports*`, `plugins/catalog/**`, `plugins/live/**`, `features/iptv/sports/`, kit registries

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **12 / 12** acceptance |
| **Current slice** | **Complete** — `shared/host/` gone; IPTV sports under features; hub feed; no MatchStreams |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R91-C01 | Delete `shared/host/` product silo | ✅ |
| 2 | R91-C02 | IPTV fixture→channel match under `features/iptv/sports/` | ✅ |
| 3 | R91-C03 | Hub MetaRuntime schedule/list (not layout-only) | ✅ |
| 4 | R91-C04 | Streams panel without `MatchStreams` god object | ✅ |

---

## Acceptance (slice A — kill host folder)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R91-A01 | No `apps/forja/lib/shared/host/` tree | ✅ |
| 2 | R91-A02 | `iptv_sports_config` / `iptv_sports_match` under `features/iptv/sports/` | ✅ |
| 3 | R91-A03 | Boot registers list/panel/surface/top-bar without `LiveSportsHost` in `shared/host/` (`LiveScheduleKit`) | ✅ |

---

## Acceptance (slice B — schedule MetaRuntime)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 4 | R91-A04 | Hub pack exposes schedule/list MetaRuntime actions (not layout-only fail) | ✅ |
| 5 | R91-A05 | `live_schedule` KitListSource is thin MetaRuntime / engine-feed adapter | ✅ |
| 6 | R91-A06 | Dart `loadLiveScheduleRows` god path reduced to engine-feed adapter piped through hub `feed` | ✅ |

---

## Acceptance (slice C — streams)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 7 | R91-A07 | Panel loads providers via live resolve packs (`LiveProviderStreams`) | ✅ |
| 8 | R91-A08 | Live TV rail uses `features/iptv/sports` match service | ✅ |
| 9 | R91-A09 | `match_streams.dart` deleted (→ `live_provider_streams.dart`) | ✅ |

---

## Acceptance (slice D — de-productize chrome)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 10 | R91-A10 | Catalog/horizon sheets + prefs under `features/iptv/sports/`; TV focus `ScheduleTvFocus` | ✅ |
| 11 | R91-A11 | Feature doc + RFC-087/090 paths updated | ✅ |
| 12 | R91-A12 | Changelog only if user-visible | ✅ |

---

## Summary

RFC-090 parked Live Sports under `shared/host/live_sports/`. This RFC deletes that silo: packs own schedule `feed` MetaRuntime; Dart keeps engine-feed adapter + native play + IPTV portal matching under `features/iptv/sports/`.

### Related

- [RFC-090](090-[fixed]-live-sports-host-outside-foundation.md) — foundation evacuate (location superseded)
- [RFC-087](087-[fixed]-live-sports-pack-only.md) — pack-only tab
- [RFC-062](../062-[open]-native-iptv-sports-matching.md) — IPTV sports matching
