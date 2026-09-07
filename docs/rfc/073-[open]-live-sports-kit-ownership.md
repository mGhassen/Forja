# RFC-073: Live Sports kit ownership (post–RFC-071)

**Status:** open  
**Depends on:** [RFC-071](fixed/071-[fixed]-live-sports-hub-kit.md) · [RFC-070](070-[partial]-catalog-hub-protocol.md) · [RFC-062](062-[open]-native-iptv-sports-matching.md)  
**Area:** `features/live_matches/streams/`, `plugins/hubs/live_sports/`, host services

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 4** components · **4 / 4** acceptance (kill modes) · **3 / 4** acceptance (kit browse) · **3 / 4** acceptance (details + services) · **2 / 2** acceptance (platform services) · **2 / 3** acceptance (god-folder teardown) |
| **Current slice** | `live_schedule/` gone → `streams/` panel host; kit browse under `browse/`; R73-A17 panel detach still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-C01 | Remove `LiveModeRegistry` / `_LiveMatchesServer` / mode prefs — capability flags only | ✅ |
| 2 | R73-C02 | Browse chrome as generic kit composition (catalog/horizon sheets, sport chips, grid) — not a full-page host takeover | 🔄 |
| 3 | R73-C03 | Match details as kit details — Providers (live JS + Stremio) / Live TV rails | 🔄 |
| 4 | R73-C04 | Host service `iptv_sports_match` (portal channel search) callable from hub/details flow | ✅ |

---

## Acceptance (kill modes)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A01 | No `LiveModeId` / `LiveModeRegistry` / `live_matches_mode_v1` write path in host | ✅ |
| 2 | R73-A02 | Schedule browse always uses catalog schedule; no `_server` branch | ✅ |
| 3 | R73-A03 | Details still loads Providers (live + Stremio) and Live TV when IPTV sports enabled | ✅ |
| 4 | R73-A04 | Host tests drop mode-registry contracts; feature doc has no mode chip | ✅ |

---

## Acceptance (kit browse)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A05 | Pack layout composes schedule from generic kit widgets + thin `live_schedule` data source | ✅ |
| 2 | R73-A06 | Catalog / horizon / sport-chip chrome is kit or shared shell — not god-state mixins | 🔄 |
| 3 | R73-A07 | TV D-pad graph uses shared recipes — not Live-only focus IDs baked into domain | ✅ |
| 4 | R73-A08 | `LiveSportsHubPage` no longer owns browse+details+play as one state object | ✅ |

---

## Acceptance (details + services)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A09 | Open match → kit / hub details surface (`open.surface: live`) | 🔄 |
| 2 | R73-A10 | Providers rail resolves live JS + Stremio without mode enum | ✅ |
| 3 | R73-A11 | Live TV rail calls host IPTV match service (not inlined matcher UI in `live_schedule`) | ✅ |
| 4 | R73-A12 | Native player only — Forja Live never embed-falls back | ✅ |

---

## Acceptance (platform services)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A13 | Streams panel registered on `CatalogHostListRegistry` — browse resolves by opaque source id | ✅ |
| 2 | R73-A14 | Live Sports play paths open via kit `openForjaLiveNativePlayer` (shared `IptvPtPlayerScreen`) | ✅ |

---

## Acceptance (god-folder teardown)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A15 | Delete unreachable full-browse hub UI; `LiveSportsHubPage` is panel-only | ✅ |
| 2 | R73-A16 | Rename `live_schedule/` → `streams/`; browse shell under `browse/` | ✅ |
| 3 | R73-A17 | Detach streams panel + play from hub `part` library (no god State) | ⬜ |

---

## Summary

RFC-071 relocated Live Sports under kit then RFC-085 moved it to `features/live_matches/`, but **browse/play stayed a host god-page** with a leftover **mode** model (Forja Live / Forja Sports / Stremio) that the product already abandoned.

**Product contract (target):**

| Layer | Owns |
|-------|------|
| `plugins/hubs/live_sports` | optional layout skin only |
| `plugins/live/**` | match scrape + stream resolve |
| Host kit (generic) | match list, dense tiles, panel slot |
| Host registry | list source + panel host by opaque id (`live_schedule`) |
| Host services | IPTV portal match/search, Forja live play (`openForjaLiveNativePlayer`) |
| Shared player | `IptvPtPlayerScreen` — same native player as IPTV |

**Modes are dead.** Browse = catalog schedule. Resolve choice = **Providers** vs **Live TV** on match details. Settings toggles remain capability flags (catalogs enabled, IPTV sports on, Stremio live addons installed) — not a top-bar mode picker.

### Shipped this slice

- `LiveSportsBrowseShell` mounts **`CatalogKitListWidget`** (`style: list` → `HubLiveMatchDenseTile`) from `LiveScheduleCatalogSource` — not a wrap of the god browse UI
- Sport chips on the browse shell; panel via `CatalogHostListRegistry.resolvePanel` → `LiveSportsStreamsPanelHost` → hub `panelOnly`
- Kit play service `openForjaLiveNativePlayer` — dispatch + streams panel use it (peer of portal `catalog_iptv_play`)
- `IptvSportsMatchService` — Live TV / ESPN / broadcast match path
- `HubLiveScheduleSource` / `loadLiveScheduleRows` — engine catalog → `CatalogMetaItem`
- CatalogShell mounts via `wantsHostBody` — no Live-named early return
- `LiveSportsTvRows` shared focus ids
- Timeline view **deleted**
- Streams panel file `live_streams_panel.dart` (still hub `part`)
- `LivePlayKit` pending cross-hub open
- **God full-browse UI deleted** — hub `LiveSportsHubPage` is panel-only streams host; browse chrome/grid/cards/sheets removed; folder renamed `live_schedule` → `streams`; browse shell under `browse/`

### Still open

- Catalog / horizon top-bar sheets not yet kit-composed (R73-A06 — sport chips on kit shell; hub copies of Catalog/Schedule chrome deleted)
- Full detach of streams panel from hub `part` library (panel remains temporary streams library under `streams/`)
- `open.surface: live` still tab-switch / panel, not a standalone kit details route (R73-A09)

### Slices

1. **Kill modes** — ✅
2. **Kit browse** — 🔄 (list is kit; god browse torn down; catalog/horizon sheets still open)
3. **Details + IPTV service** — 🔄 (panelOnly host; still hub part)
4. **Platform services** — ✅ (panel registry + shared live play)
5. **God-folder teardown** — 🔄 (`live_schedule` deleted; panel still hub `part`s)

### Related

- [RFC-071](fixed/071-[fixed]-live-sports-hub-kit.md) — frozen relocate (modes were host-owned there)
- [live-matches feature doc](../features/live/live-matches.md)
- [RFC-062](062-[open]-native-iptv-sports-matching.md) — matcher engine
