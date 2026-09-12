# RFC-108: My List open hub binding

**Status:** open  
**Depends on:** [RFC-097](fixed/097-[fixed]-my-list-explode-host-to-packs.md) · [RFC-070](070-[partial]-catalog-hub-protocol.md)  
**Area:** `shared/engine/lists/`, `shared/engine/hub/`, My List open UX, Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** components · **20 / 20** acceptance |
| **Current slice** | Single Open-in bind sheet — open until manual QA |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R108-C01 | `hubDetailsParams` prefers `open.id` over list `uniqueId` | ✅ |
| 2 | R108-C02 | Host `ListOpenBinding` resolve + bookmark cache | ✅ |
| 3 | R108-C03 | Ambiguous / Open-with hub picker (desktop + touch) | ✅ |
| 4 | R108-C04 | Cross-hub bind via hub `search` when ids incompatible | ✅ |
| 5 | R108-C05 | My List **pack** settings (`hub_select`) for open defaults | ✅ |
| 6 | R108-C06 | TV long-press Open-with + feature doc | ✅ |
| 7 | R108-C07 | Single **Open in…** bind sheet (hub chips + search + ranked hits) | ✅ |

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
| 17 | R108-A17 | Open-with search ranks exact/near title first; year-stripped retry; strong match skips picker | ✅ |

---

## Acceptance (slice 4 — settings / TV / docs)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 12 | R108-A12 | My List pack settings: `hub_select` defaults (installed hub options; `listOpenDefault`) | ✅ |
| 13 | R108-A13 | Defaults apply only when row has compatible ids and no stored binding | ✅ |
| 14 | R108-A14 | TV long-press Open-with parity | ✅ |
| 15 | R108-A15 | Feature doc describes open binding / Open with | ✅ |
| 16 | R108-A16 | Changelog bullets for user-visible slices | ✅ |

---

## Acceptance (slice 5 — bind sheet UX)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 18 | R108-A18 | One Open-in sheet replaces hub AlertDialog + match AlertDialog | ✅ |
| 19 | R108-A19 | Sheet: title poster, hub chips, editable query, ranked hits with Best match | ✅ |
| 20 | R108-A20 | Compatible hub shows direct Open row (no search list) | ✅ |

---

## Summary

My List must open titles into the right installed catalog hub without the pack inventing a hub inventory. Local Asian Drama / Anime bookmarks already carry opaque `open`; Simkl stubs are mostly TMDB. When binding is missing or ambiguous — or the user wants to rebind — the host shows one **Open in…** sheet (hub chips + title search + ranked hits), caches `open` + `pluginId` on the bookmark, and supports cross-id bind via hub `search`.

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
