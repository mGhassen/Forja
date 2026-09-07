# RFC-090: Live Sports host outside foundation

**Status:** fixed  
**Depends on:** [RFC-085](../085-[partial]-catalog-kit-generic-only.md) · [RFC-087](087-[fixed]-live-sports-pack-only.md)  
**Area:** `shared/host/live_sports/`, `shared/foundation/`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** components · **4 / 4** acceptance |
| **Current slice** | **Complete** — evacuated to `shared/host/live_sports/` |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R90-C01 | Live Sports Dart host under `shared/host/live_sports/` (not `foundation/services/live/`) | ✅ |
| 2 | R90-C02 | Foundation registries only: `HostListRegistry`, `MetaSurfaceOpen`, `KitTopBarHostHooks` | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R90-A01 | No `shared/foundation/services/live/` tree | ✅ |
| 2 | R90-A02 | `kit_open` / `kit.topBar` do not import Live Sports host modules | ✅ |
| 3 | R90-A03 | Boot `LiveSportsHost.ensureRegistered` wires list/panel + surface + top-bar hooks | ✅ |
| 4 | R90-A04 | RFC-085 / RFC-087 docs + changelog describe host path | ✅ |

---

## Summary

RFC-087 kept schedule/stream orchestration under foundation. That put product scent (`LiveSports*`, IPTV sports match, MatchStreams) in the app-wide kit root.

**Rule:** foundation stays generic registries + kit UI. Live Sports host glue registers opaque `live_schedule` / `open.surface: live` / top-bar sheets from `shared/host/live_sports/`.

### Related

- [RFC-087](087-[fixed]-live-sports-pack-only.md) — pack-only tab (location of host services corrected here)
- [RFC-085](../085-[partial]-catalog-kit-generic-only.md) — foundation purity
