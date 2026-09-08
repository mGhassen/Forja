# RFC-095: Foundation like shadcn — design alone, data alone

**Status:** fixed  
**Depends on:** [RFC-085](../085-[partial]-catalog-kit-generic-only.md) · [RFC-025](025-[fixed]-flat-cinematic-shell.md) · [RFC-092](092-[fixed]-delete-root-app-live-sports.md)  
**Area:** `shared/foundation/`, `features/**`, design system rules

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **10 / 10** acceptance |
| **Current slice** | Complete — Portals / list status / IPTV play hooks / resolve panel / live product tree removed |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R95-C01 | Meta contract: foundation components = props/callbacks only; features own data | ✅ |
| 2 | R95-C02 | Portals design: `KitPortalsChip`, `KitSidePanelOverlay`, `KitPortalListPanel` | ✅ |
| 3 | R95-C03 | Portals data: IPTV adapters + `IptvPortalsChromeHooks`; delete `LiveSportsPortalChrome` | ✅ |

---

## Acceptance (slice A — Portals reference)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R95-A01 | `KitPortalsChip` / overlay / list panel take props only — no `IptvController`, no `features/` imports | ✅ |
| 2 | R95-A02 | IPTV maps controller → chip/list props; same design used by catalog + kit Live Sports trailing | ✅ |
| 3 | R95-A03 | `IptvPortalsChromeHooks` registers `KitTopBarHostHooks`; no `LiveSports*Chrome` under IPTV | ✅ |
| 4 | R95-A04 | Cursor rules state design-alone / data-alone for `components/` | ✅ |
| 5 | R95-A05 | Inventory of foundation → `features/` smells documented for slices B–E | ✅ |
| 6 | R95-A06 | Feature / architecture docs point at foundation Portals chrome + IPTV data path | ✅ |

---

## Acceptance (deferred slices)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 7 | R95-A07 | Slice B — `KitListStatusButton`: dumb control + feature wiring (no Riverpod/Simkl in chrome) | ✅ |
| 8 | R95-A08 | Slice C — `kit_details_screen` / `iptv_open` / play blocks: inject hosts; IPTV stays in feature | ✅ |
| 9 | R95-A09 | Slice D — `kit_resolve_panel_host` registers loaders from feature; no direct match import | ✅ |
| 10 | R95-A10 | Slice E — delete or move leftover `foundation/services/live/` product tree | ✅ |

---

## Summary

**Rule:** `shared/foundation/components` (and primitives) are a **shadcn-style design system**: props in, callbacks out. Features and boot hooks own controllers/stores and fill those props. Swap the data source; chrome stays.

**Wrong:** `IptvController` inside a “shared” chip; `LiveSportsPortalChrome` under `features/iptv/portal_sports/`; foundation importing match/play screens.

**Right:** `KitPortalsChip(label, health, seats, onTap)` ← IPTV adapter; `KitSidePanelOverlay(open, child, panel)`; match/config remain IPTV **data**.

### Portals pattern (slice A)

```
KitTopBar trailing → KitPortalsChip
KitSidePanelOverlay → KitPortalListPanel (header/search/body slots)
IptvController → view props → Kit*
```

### Inventory (foundation → features — resolved)

| Path | Smell | Slice |
|------|-------|-------|
| `components/chrome/kit_list_status_*` | Riverpod / Simkl inside chrome | B ✅ |
| `components/details/kit_sources.dart` | settings providers | C ✅ (`KitPanelSourceFlags`) |
| `blocks/details/kit_details_screen.dart` | IPTV models + settings providers | C ✅ (`KitIptvPlayHooks` + `KitPanelSourceFlagsHooks`) |
| `features/iptv/open/iptv_open.dart` (+ play) | IPTV network/storage/player | C ✅ (moved out of foundation) |
| `services/panel/kit_resolve_panel_host.dart` | portal sports match + player | D ✅ (`KitResolveStreamsHooks`) |
| `services/panel/kit_match_details_page.dart` | IPTV health probe | D ✅ |
| `services/live/*` | leftover product live tree | E ✅ (deleted) |

### Related

- [RFC-085](../085-[partial]-catalog-kit-generic-only.md) — shadcn folder layout
- [RFC-092](092-[fixed]-delete-root-app-live-sports.md) — IPTV match under portal data (not Live Sports product tree)
- [forja-design-system](../../../.cursor/rules/forja-design-system.mdc) · [forja-shared-ui](../../../.cursor/rules/forja-shared-ui.mdc)
