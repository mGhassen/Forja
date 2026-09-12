# RFC-108: My List open hub binding

**Status:** open  
**Depends on:** [RFC-097](fixed/097-[fixed]-my-list-explode-host-to-packs.md) · [RFC-070](070-[partial]-catalog-hub-protocol.md)  
**Area:** `shared/engine/lists/`, `shared/engine/hub/`, My List open UX, Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **16 / 16** acceptance |
| **Current slice** | All slices landed — open until manual QA of picker / TV long-press |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R108-C01 | `hubDetailsParams` prefers `open.id` over list `uniqueId` | ✅ |
| 2 | R108-C02 | Host `ListOpenBinding` resolve + bookmark cache | ✅ |
| 3 | R108-C03 | Ambiguous / Open-with hub picker (desktop + touch) | ✅ |
| 4 | R108-C04 | Cross-hub bind via hub `search` when ids incompatible | ✅ |
| 5 | R108-C05 | Settings defaults per engine type | ✅ |
| 6 | R108-C06 | TV long-press Open-with + feature doc | ✅ |

---

## Acceptance (slice 0 — details id)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R108-A01 | `hubDetailsParams` uses non-empty `open.id` for `params.id` | ✅ |
| 2 | R108-A02 | Host unit test: drama row `uniqueId` catalog_… + `open.id` → params id is open id | ✅ |

---

## Acceptance (slice 1 — binding)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 3 | R108-A03 | `ListOpenBinding` discovers candidates via `types[]` + `details` (no pack-id allowlist) | ✅ |
| 4 | R108-A04 | Resolve order: stored open+pluginId → single candidate → ambiguous | ✅ |
| 5 | R108-A05 | Choice persists via `BookmarkStore.upsertCatalog` (`open` + `pluginId`) | ✅ |
| 6 | R108-A06 | `openLegacyListItem` / catalog list open use binding resolve | ✅ |

---

## Acceptance (slice 2 — picker)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 7 | R108-A07 | Ambiguous / missing open shows hub picker (nav labels) | ✅ |
| 8 | R108-A08 | Desktop secondary-click / touch long-press opens **Open with…** | ✅ |
| 9 | R108-A09 | Valid cached hub open opens directly (no picker spam) | ✅ |

---

## Acceptance (slice 3 — search bind)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 10 | R108-A10 | Choosing a hub with incompatible ids runs hub `search` by title | ✅ |
| 11 | R108-A11 | User picks a search hit → open cached on bookmark → details | ✅ |

---

## Acceptance (slice 4 — settings / TV / docs)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 12 | R108-A12 | Settings → My List: default hub per engine type | ✅ |
| 13 | R108-A13 | Defaults apply only when row has compatible ids and no stored binding | ✅ |
| 14 | R108-A14 | TV long-press Open-with parity | ✅ |
| 15 | R108-A15 | Feature doc describes open binding / Open with | ✅ |
| 16 | R108-A16 | Changelog bullets for user-visible slices | ✅ |

---

## Summary

My List must open titles into the right installed catalog hub without the pack inventing a hub inventory. Local Asian Drama / Anime bookmarks already carry opaque `open`; Simkl stubs are mostly TMDB. When binding is missing or ambiguous — or the user wants to rebind — the host shows a picker over installed `details` hubs (by `types[]` + nav label), caches `open` + `pluginId` on the bookmark, and supports cross-id bind via hub `search`.

**Prerequisite:** details params must prefer `open.id` so list `uniqueId` (`catalog_<plugin>_<id>`) does not break KissKH / AniList details.

### Goals

- Pack-agnostic hub discovery (`PluginNavRegistry` / `types` + `details`)
- Bookmark as binding cache
- First-open picker only when needed; Open-with for corrections
- Settings defaults per engine type for Simkl stubs with compatible ids

### Related

- [RFC-097](fixed/097-[fixed]-my-list-explode-host-to-packs.md) — My List pack feed
- [my-list feature](../features/movies-tv/my-list.md)
- [issue 260](../issues/260-[open]-host-hardcodes-specific-plugins.md) — no pack-id allowlists
