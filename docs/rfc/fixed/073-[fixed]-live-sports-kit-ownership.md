# RFC-073: Live Sports kit ownership (post–RFC-071)

**Status:** fixed  
**Depends on:** [RFC-071](071-[fixed]-live-sports-hub-kit.md) · [RFC-070](../070-[partial]-catalog-hub-protocol.md) · [RFC-062](../062-[open]-native-iptv-sports-matching.md)  
**Area:** `features/live_sports/`, `shared/foundation/services/live/`, `plugins/hubs/live_sports/`, host services

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** components · **4 / 4** kill modes · **4 / 4** kit browse · **4 / 4** details + services · **2 / 2** platform · **4 / 4** teardown · **3 / 3** kill silo · **1 / 1** domain home · **3 / 3** pack wire |
| **Current slice** | Pack data + kit chrome + host services — complete |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-C01 | Remove `LiveModeRegistry` / `_LiveMatchesServer` / mode prefs — capability flags only | ✅ |
| 2 | R73-C02 | Browse chrome as generic kit composition (catalog/horizon sheets, sport chips, grid) — not a full-page host takeover | ✅ |
| 3 | R73-C03 | Match details as kit details — Providers / Live TV via KitSourcesPanel + MatchStreams | ✅ |
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
| 2 | R73-A06 | Catalog / horizon / sport-chip chrome is kit or shared shell — not god-state mixins | ✅ |
| 3 | R73-A07 | TV D-pad graph uses shared recipes — not Live-only focus IDs baked into domain | ✅ |
| 4 | R73-A08 | `LiveSportsHubPage` no longer owns browse+details+play as one state object | ✅ |

---

## Acceptance (details + services)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A09 | Open match → kit / hub details surface (`open.surface: live`) | ✅ |
| 2 | R73-A10 | Providers rail resolves live JS + Stremio without mode enum | ✅ |
| 3 | R73-A11 | Live TV rail calls host IPTV match service (not inlined matcher UI in `live_schedule`) | ✅ |
| 4 | R73-A12 | Native player only — Forja Live never embed-falls back | ✅ |

---

## Acceptance (platform services)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A13 | Streams panel registered on `HostListRegistry` — browse resolves by opaque source id | ✅ |
| 2 | R73-A14 | Live Sports play paths open via kit `openForjaLiveNativePlayer` (shared `IptvPtPlayerScreen`) | ✅ |

---

## Acceptance (god-folder teardown)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A15 | Delete unreachable full-browse hub UI; `LiveSportsHubPage` is panel-only | ✅ |
| 2 | R73-A16 | Rename `live_schedule/` → `streams/`; browse shell under `browse/` | ✅ |
| 3 | R73-A17 | Detach streams panel + play from hub `part` library (no god State) | ✅ |
| 4 | R73-A18 | Feature folder My List–thin — no `streams/` under feature; panel in `shared/foundation/services/live/panel` | ✅ |

---

## Acceptance (kill shared/live silo)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A19 | `MatchStreams` service loads Providers / Live TV from kit `legacyRow`; play via `openForjaLiveNativePlayer` | ✅ |
| 2 | R73-A20 | Thin `LiveSportsStreamsPanelHost` builds `KitSourcesPanel` only — no `LiveSportsStreamsPage` | ✅ |
| 3 | R73-A21 | `shared/foundation/services/live/panel/` deleted; remaining live libs under `shared/services/sports/` (+ feature prefs/filters); no `shared/foundation/services/live/` tree | ✅ |

---

## Acceptance (live libs domain home)

Supersedes the **parking path** in R73-A21 only. Panel silo (`shared/foundation/services/live/panel/`) stays gone. Host live/sports libs move out of the `services/` grab-bag.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A22 | Host live/sports libs under `shared/foundation/services/live/`; `shared/services/` keeps `app/` · `update/` · `tracker` only | ✅ |

---

## Acceptance (pack wire + host services)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R73-A23 | Catalog packs stamp stable wire (`kind` / `startsAt` / `open`) via `_wire.js`; host `liveMetaFromScheduleRow` maps preferred keys | ✅ |
| 2 | R73-A24 | Providers resolve via engine plugins only — no host streamed.pk / embed.st invent paths | ✅ |
| 3 | R73-A25 | Host ESPN browse merge removed; IPTV uses pack `sportMatchGame` + broadcast catalogs | ✅ |

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

- Tab mounts **`KitShell`** + host layout → **`KitListWidget`** (`style: list` → `KitEventDenseTile`) from `LiveScheduleCatalogSource` (`wantsHostBody: false`)
- Sport chips via kit list; panel via `HostListRegistry.resolvePanel` → `LiveSportsStreamsPanelHost` → **`KitSourcesPanel`** + **`MatchStreams`**
- Host sports libs under `shared/foundation/services/live/` (`live_stream_engine`, `match_streams`, `iptv_sports_match`, schedule/team/stremio helpers); feature prefs/filters under `features/live_sports/`
- Feature folder stays thin (host + layout + list source + panel host); opaque ids `live_matches` / `live_schedule` unchanged
- Kit play service `openForjaLiveNativePlayer` — MatchStreams uses it (peer of portal `catalog_iptv_play`)
- `IptvSportsMatchService` — Live TV / broadcast match path (pack `sportMatchGame`; standalone library)
- `LiveScheduleListSource` / `loadLiveScheduleRows` — engine catalog → `MetaItem`
- Timeline view **deleted**; browse shell **deleted**; **`shared/foundation/services/live/panel/` silo deleted** (R73-A21); libs restored under `shared/foundation/services/live/` (R73-A22)


### Shipped (pack data + kit + host services)

- Kit chrome: `catalog` + `horizon` menus on host default layout and hub pack layout; prefs hydrate defaults; horizon filters `loadLiveScheduleRows`
- `open.surface: live` → `LivePlayKit` tab switch + `KitListWidget` pending select opens streams panel
- Catalog pack prelude `_wire.js` stamps `kind` / `startsAt` / `open`; host mapper prefers those keys
- `MatchStreams` resolve is engine-plugin only (no host streamed.pk invent / Rust `streamed_streams` fallback)
- Host ESPN browse merge API removed; Live TV IPTV matching uses pack `sportMatchGame` + broadcast plugins

### Still open

- None for this RFC.

### Slices

1. **Kill modes** — ✅
2. **Kit browse** — ✅ (catalog / horizon kit menus + sport chips; horizon filters load)
3. **Details + IPTV service** — ✅ (`open.surface: live` → tab + panel select)
4. **Platform services** — ✅ (panel registry + shared live play)
5. **God-folder teardown** — ✅ (thin feature; historical R73-A15–A18)
6. **Kill shared/live silo** — ✅ (R73-A19–A21)
7. **Live libs domain home** — ✅ (R73-A22)
8. **Pack wire + host services** — ✅ (R73-A23–A25)

### Related

- [RFC-071](071-[fixed]-live-sports-hub-kit.md) — frozen relocate (modes were host-owned there)
- [live-matches feature doc](../../features/live/live-matches.md)
- [RFC-062](../062-[open]-native-iptv-sports-matching.md) — matcher engine
