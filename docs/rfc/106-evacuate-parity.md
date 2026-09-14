# RFC-106 G14-D — Evacuate parity checklist

**Status:** wiring complete (A18 ✅) — **not** QA sign-off (A19 ⏭️)  
**RFC:** [fixed/106-[fixed]-forja-foundation-design-system-package.md](fixed/106-[fixed]-forja-foundation-design-system-package.md)  
**Plan:** G14-D (do not edit `.cursor/plans`)

**Legend:** ✅ surface works via current paths · ⬜ missing · 🔄 partial

QA Q1–Q12 remains unsigned — see G14-E. This file tracks **evacuate wiring only**. Unsigned QA does **not** block pack / kit / engine work.

**Law:** Forja root is a **pack-product host** — generic only. Product lives in packs. `shared/host/` is **not** a product destination ([R106-A31](fixed/106-[fixed]-forja-foundation-design-system-package.md)).

---

## G14-D surfaces

| Old foundation surface | Must still work via | Current path | Status |
|------------------------|---------------------|--------------|--------|
| Live match details | Kit + pack feed | `shared/shell/kit/` + engine live + hub packs | ✅ |
| Live schedule list/cards | `kit.list` + pack chrome | Generic kit list; Live Sports pack | ✅ |
| Vertical filters / platforms menu | LogoMenuRail + shell `showMenu` | DS `LogoMenuRail` + `VerticalMenu` | ✅ |
| Sources / resolve panel | Kit hooks + SourcesPanel | `shared/player/sources/**` | ✅ |
| Follow / list status | Engine lists + pack My List | `shared/engine/lists/**` + My List hub | ✅ |
| Pack install / update / keychain | Engine + settings feature | `shared/engine/packs/**` + `features/settings/packs/**` (+ `host/update|account` leftovers) | ✅ |
| Torrent sources UI | Player sources | `shared/player/sources/**` | ✅ |
| Watch history | App prefs store | `shared/host/watch/watch_history.dart` (leftover path) | ✅ |
| TMDB / enrich images | Pack enrich companions | Pack `enrich` + kit render-only | ✅ |
| MetaRuntime / plugin_nav / HostListRegistry | Boot registration | `shared/engine/runtime/**` + host layout kit | ✅ |
| Deeplink `forja://catalog/...` | Package protocol | `forja_foundation/protocol` | ✅ |

---

## Open path notes (wiring, not QA)

| Surface | Expected open path |
|---------|-------------------|
| Live match details | Kit list → match details via pack `open` / kit paint |
| Live schedule | Hub pack `feed` + opaque `live_schedule` registry |
| Follow / list | My List hub + engine list follow |
| Pack install | Settings Forja Packs + install banner |
| App update / Keychain | `shared/host/update` · Settings About (`features/settings/about/macos_keychain_consent_screen.dart`) |
| Vertical filters | Home platforms → LogoMenuRail |
| Sources panel | `shared/player/sources/**` |
| Torrent | Media details torrent panels under player sources |

---

## Invariants (G14-G)

| # | Rule | Status |
|--:|------|--------|
| 1 | App compiles after evacuate PR (shims bridge) | ✅ |
| 2 | No pack JSON required unless forja-packs PR first | ✅ |
| 3 | No user-facing entry removed without replacement | ✅ |
| 4 | Shim death separate after Q1–Q12 | ⬜ |
| 5 | Part 1 evacuate includes wiring enough to compile | ✅ |
| 6 | No new product trees under `shared/host/` | ✅ |

---

## Historical — G11 host dump (retracted)

G11 briefly listed product under `shared/host/{live_sports,lists,sources,…}`. That destination is **wrong** and those trees are **gone**.

| Was (G11 mistake) | Now |
|-------------------|-----|
| `host/live_sports/` | Packs + `shared/engine/live/**` + kit |
| `host/lists/` | Packs + `shared/engine/lists/**` |
| `host/sources/**` | `shared/player/sources/**` |
| Catalog kit / MetaRuntime / `kit_shell` | `shared/shell/kit/**` + `shared/engine/hub/**` |

---

## Leftover app-only paths (not a product layer)

These remain under `apps/forja/lib/shared/host/` **only** because they are app chrome / prefs, not hub product. Do **not** add catalog, live, lists, or sources here. Rename later is fine; expanding the silo is not.

| Path | Role |
|------|------|
| `packs/` | Pack install UI, settings store, connected auth, `PackAssets` |
| `update/` | App update dialog + progress banner |
| `account/` | macOS Keychain consent |
| `watch/` | Continue / watched prefs store |
| `search/` | Host search engine behind kit (`host_search`) — now `engine/runtime/search/` |
| `details/` | README only — packs own enrich |

---

## Correction — Live Sports UX is the pack

`engine/live/kit_schedule_*` and `LiveSportsHubMergeUpgrade` are **deleted**. Horizon / view items live on `hubs/live_sports/live_sports.js`. Engine `LiveFeedQuery` takes opaque strings (`airing` / `h1`). Kit live boot only registers opaque schedule + catalog options from the engine.

---

## Correction — cards are kit.list, not a Live Sports module

`KitListLiveCards` / `KitListHostHooks` are **deleted**. Event cards / match details paint from kit list entries. `MatchEvent` stays in `engine/live` for merge/resolve/IPTV match. Badge URLs are pack-absolute.

---

## Correction — kind icons and list search are pack chrome

Host mood helpers only resolve pack **icon tokens**. `kindIcons` + search `placeholder` live on the Live Sports hub pack. Horizon chip default is the pack `default`.

---

## Correction — panel tabs are pack chrome

`kit.list.panelTabs` / `panelTab` declare Providers / Live TV (or any tabs). Default browse category tab ids are empty. Tab icons come from pack `icon`. IPTV adapter loads pack tab `action` (`liveTv`) — not a hardcoded chrome id.
