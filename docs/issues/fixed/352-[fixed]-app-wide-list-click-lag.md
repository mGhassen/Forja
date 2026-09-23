# 352 — App-wide list clicks lag (pack index + panel rebuilds)

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** All hubs · Sources panel · Portals · `openMetaItem` · `PluginRegistry`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I352-T01 | In-memory `listPacksRaw` cache (invalidate on write / profile scope) | ✅ |
| 2 | I352-T02 | Open / capability hot path uses raw + sync peek — never `listPacks` repair on poster tap | ✅ |
| 3 | I352-T03 | Sources panel: chip/kind/pick-in-flight via notifiers — do not rebuild frosted shell + IntrinsicHeight tiles | ✅ |
| 4 | I352-T04 | Portals health: per-row listenables (stop panel `setState` on every probe) | ✅ |
| 5 | I352-T05 | Catalog channel grid: selection via `ValueNotifier` (stop grid `setState` on hover/focus) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I352-A01 | Home / Anime / Search poster tap opens details without prefs pause (warm packs) | ⬜ |
| 2 | I352-A02 | Sources chip / kind switch stays fluid with many streams | ⬜ |
| 3 | I352-A03 | Portals hover probe does not hitch the whole panel | ⬜ |
| 4 | I352-A04 | IPTV channel hover/focus does not rebuild the whole grid | ⬜ |

---

## Summary

User: every list click feels dead — portals, Sources, posters, not IPTV-only.

IPTV-specific awaits ([349](349-[fixed]-iptv-favorite-star-lag.md), [351](../351-[open]-iptv-click-lag-await-catalog-ffi.md)) were real but not the shared multiplier.

### Root (shared)

Every poster / rail / search open called `openMetaItem` → `pluginHasDetails` → `listKitPlugins` → **`EngineService.listPacks()`** which runs `ensureOfficialInstalled` + **`repairMissingScripts`** + double prefs decode **before** `pushShellRoute`.

### Root (Sources / dense lists)

Chip / kind / pick-in-flight still `setState` the whole frosted Sources panel (IntrinsicHeight tiles). Portal health and channel grid selection still parent-`setState` on hover.

### Shipped

- Pack index memory cache
- Capability / open path uses `listPacksRaw` + sync peek when warm
- Surface opens (stream) skip pack remap entirely
- Sources: pick overlay uses `ValueNotifier` (no list rebuild); stream tiles drop `IntrinsicHeight`; kind tab paints before abort/fetch
- Portals: `PortalHealthTracker.listenableFor` + `PortalListView` per-row tick — panel no longer `setState` on probe
- Channel grid: selection `ValueNotifier` + card `selectionIndexListenable` — hover/focus does not grid-`setState`

### Related

- [337](337-[fixed]-sources-panel-jank-many-streams.md) — fetch paint coalesce (not tap rebuild)  
- [349](349-[fixed]-iptv-favorite-star-lag.md) · [351](../351-[open]-iptv-click-lag-await-catalog-ffi.md)
