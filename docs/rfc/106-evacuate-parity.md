# RFC-106 G14-D — Evacuate parity checklist

**Status:** open (wiring inventory — **not** QA sign-off)  
**RFC:** [106-[open]-forja-foundation-design-system-package.md](106-[open]-forja-foundation-design-system-package.md)  
**Plan:** G14-D (do not edit `.cursor/plans`)

**Legend:** ✅ host path + foundation stub exist · analyze clean on moved trees · ⬜ not evacuated / host adapter incomplete · 🔄 partial

QA Q1–Q12 remains unsigned — see G14-E. This file tracks **evacuate wiring only**.

---

## G14-D surfaces

| Old foundation surface | Must still work via | Host / stub | Status |
|------------------------|---------------------|-------------|--------|
| Live match details | Host + `DetailsBlock` | `shared/kit/kit_match_details_page.dart` + `KitEventPaint` | ✅ |
| Live schedule list/cards | `kit.list` `style: cards` + `KitEventPaint` | Generic kit list; no Live Sports hooks | ✅ |
| Vertical filters / platforms menu | LogoMenuRail + shell `showMenu` | `vertical_filters*.dart` wraps DS `LogoMenuRail` + `VerticalMenu` | ✅ |
| Sources / resolve panel | Kit hooks + SourcesPanel | Generic panel stays foundation; Live TV browse + `KitResolvePanelHost` → `host/sources/panel/` | ✅ |
| Follow / list status | Host data + ListStatus widgets | `host/lists/**` + follow stubs | ✅ |
| Pack install / update / keychain | Host entry points | `host/packs/**` + `host/update/**` + `host/account/**` + stubs | ✅ |
| Torrent sources UI | Host torrent panels | `host/sources/torrent/**` + foundation stubs | ✅ |
| Watch history | Host watch store | `host/watch/watch_history.dart` + stub | ✅ |
| TMDB / enrich images | Absolute URLs + host enrich hooks | `TmdbDetailsEnrich` → `KitDetailsHostHooks`; pack URLs always | ✅ |
| MetaRuntime / plugin_nav / HostListRegistry | Boot registration | Stays foundation (kit runtime, not product dump) | ✅ |
| Deeplink `forja://catalog/...` | Package protocol + app re-export | `forja_foundation/protocol` + foundation re-export | ✅ |

---

## Open path notes (wiring, not QA)

| Surface | Expected open path |
|---------|-------------------|
| Live match details | Kit list → `KitMatchDetailsPage` via host |
| Live schedule | `kit.list` `source: live_schedule` → `KitLiveBoot` + generic cards |
| Follow / list | My List hub + `KitListStatusButton` |
| Pack install | Settings Forja Packs + install banner |
| App update / Keychain | `host/update/UpdateDialog` · `host/account` consent |
| Vertical filters | Home platforms → LogoMenuRail |
| Sources panel | `KitSourcesPanel` (foundation) + host `KitResolvePanelHost` / Live TV browse |
| Torrent | Media details torrent panels via host |

---

## Invariants (G14-G)

| # | Rule | Status |
|--:|------|--------|
| 1 | App compiles after evacuate PR (shims bridge) | ✅ |
| 2 | No pack JSON required unless forja-packs PR first | ✅ |
| 3 | No user-facing entry removed without replacement | ✅ |
| 4 | Shim death separate after Q1–Q12 | ⬜ |
| 5 | Part 1 evacuate includes host wiring enough to compile | ✅ |

---

## Host folders (G11)

| Folder | Contents |
|--------|----------|
| `apps/forja/lib/shared/host/live_sports/` | Match/schedule/live chrome + list hooks |
| `apps/forja/lib/shared/host/packs/` | Pack UI + settings + PackAssets |
| `apps/forja/lib/shared/host/lists/` | Follow / My List product |
| `apps/forja/lib/shared/host/sources/torrent/` | Torrent panels / tiles / loading |
| `apps/forja/lib/shared/host/sources/panel/` | Live TV browse + `KitResolvePanelHost` |
| `apps/forja/lib/shared/host/details/` | TMDB enrich hooks |
| `apps/forja/lib/shared/host/watch/` | Watch history |
| `apps/forja/lib/shared/host/update/` | App update dialog + progress banner |
| `apps/forja/lib/shared/host/account/` | macOS Keychain consent |

See per-folder READMEs for leftover kit entanglement.

---

## Correction — pack surfaces are not host

`host/lists`, `host/live_sports`, `host/sources` are **gone**. Those names are pack surfaces.

| Was | Now |
|-----|-----|
| Match/schedule models + prefs | `shared/engine/live/**` |
| List-follow / merge | `shared/engine/lists/**` |
| Torrent parse | `shared/engine/models/torrent_release_metadata.dart` |
| Torrent source panels | `shared/player/sources/**` |
| Catalog boot / cards / resolve panel / my-list catalog / `plugin_nav` / MetaRuntime / `kit_shell` | `shared/kit/**` |

Catalog kit is `shared/kit/**`. Host services are `packs/`, `watch/`, `update/`, `account/`, plus `details/` (TMDB enrich still debt). Do not put catalog under `shared/host/`.

---

## Correction — Live Sports UX is the pack

`engine/live/kit_schedule_*` and `LiveSportsHubMergeUpgrade` are **deleted**. Horizon / view items live on `hubs/live_sports/live_sports.js`. Engine `LiveFeedQuery` takes opaque strings (`airing` / `h1`). `KitLiveBoot` only registers `live_schedule` + catalog options from the engine.

---

## Correction — cards are kit.list, not a Live Sports module

`KitListLiveCards` / `KitListHostHooks` are **deleted**. `KitEventCard` / `KitMatchDetailsPage` paint from `KitListEntry` (`KitEventPaint`). `MatchEvent` stays in `engine/live` for merge/resolve/IPTV match. Badge URLs are pack-absolute — host `kitEventImageUrl` does not invent `streamed.pk`.

---

## Correction — kind icons and list search are pack chrome

Host `kitMoodCircleMeta` only resolves pack **icon tokens** (`soccer`, `tv`, …). It does not map NFL / La Liga / WWE. `kindIcons` + search `placeholder` live on `hubs/live_sports/live_sports.js`. Horizon chip default is the pack `default` — host no longer hardcodes `airing|1h`. `KitScheduleEventSearch` is `KitListEventSearch`.

---

## Correction — panel tabs are pack chrome

`kit.list.panelTabs` / `panelTab` declare Providers / Live TV (or any tabs). Host `KitSourcesPanel` default `browseCategoryTabIds` is empty. Tab icons come from pack `icon` (not index 0/1). IPTV adapter loads pack tab `action` (`liveTv`) — not chrome id `live_tv`.
