# RFC-106: Forja foundation design system package

**Status:** fixed  
**Depends on:** [RFC-095](095-[fixed]-foundation-design-data-split.md) · [RFC-085](085-[fixed]-catalog-kit-generic-only.md) · [RFC-025](025-[fixed]-flat-cinematic-shell.md)  
**Area:** `packages/forja_foundation`, `apps/forja`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **9 / 9** components · **14 / 14** Part 1 · **7 / 8** Part 2 (1 ⏭️ QA) · **5 / 5** body evacuate · **3 / 3** deeper paint · **3 / 3** pack-product law |
| **Current slice** | Shipped — A19 Q1–Q12 QA remains ⏭️ (does not block) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R106-C01 | `packages/forja_foundation` scaffold, barrels, path dep, ARCHITECTURE | ✅ |
| 2 | R106-C02 | Tokens + `ForjaThemeExtension` / `forjaThemeData()` | ✅ |
| 3 | R106-C03 | Button family — `PrimitiveButton`, `Button`, `ButtonGroup` (.separator / .text) | ✅ |
| 4 | R106-C04 | `VerticalMenu` (.item) + LogoMenuRail path (Part 1 extract) | ✅ |
| 5 | R106-C05 | Full component catalog (Toggle, Input/Field, Dialog/Sheet, …) | ✅ |
| 6 | R106-C06 | Kit layout map + widgets + blocks + protocol/kit/platform | ✅ |
| 7 | R106-C07 | Evacuate product domain from package into host adapters | ✅ |
| 8 | R106-C08 | Part 2 consumer upgrade — shims, migrate, QA, shim death | ✅ |
| 9 | R106-C09 | Pack-product host law — retract `shared/host/` as product destination | ✅ |

---

## Acceptance (Part 1 — G0–G13)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R106-A01 | **G0** Package + zones: `forja_foundation` exists; path dep; lint zones A/B; sectioned barrels; shim death deferred to Part 2 | ✅ |
| 2 | R106-A02 | **G1** Ten layers present (`tokens` … `utils`); no product `lib/` dump in package | ✅ |
| 3 | R106-A03 | **G2** Theme system: `ThemeExtension` + `forjaThemeData()`; dual DesignTokens/ShellColors path collapsed into package theme | ✅ |
| 4 | R106-A04 | **G3** Component families with variant/size/slots — Button + ButtonGroup + VerticalMenu first; no exploded peer button types as public API | ✅ |
| 5 | R106-A05 | **G4** Kit layout slot → artifact map (`kit.*`, hero, mood, continue, vertical_filters → VerticalMenu) | ✅ |
| 6 | R106-A06 | **G5** Widgets tier (composers, props + callbacks only) | ✅ |
| 7 | R106-A07 | **G6** Blocks tier (page templates) | ✅ |
| 8 | R106-A08 | **G7** Convergences (dual hero/poster stacks, naming) | ✅ |
| 9 | R106-A09 | **G8** Pull-in settings / player / shell chrome into package presentation | ✅ |
| 10 | R106-A10 | **G9** VerticalMenu extracts Home platforms flyout (not buried as vertical_filters UI) | ✅ |
| 11 | R106-A11 | **G10** protocol + kit + platform layers land with opaque contracts only | ✅ |
| 12 | R106-A12 | **G11** Domain evacuate into host folders with adapters enough to compile | ✅ |
| 13 | R106-A13 | **G12** Package quality — unit/widget tests, forbidden-import CI, README | ✅ |
| 14 | R106-A14 | **G13** Non-goals held — no React DS, no rust/player move, no pack allowlists, no backlog edits | ✅ |

---

## Acceptance (Part 2 — G14)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 15 | R106-A15 | **G14-A** Compat layer — export inventory; old `shared/foundation/**` paths resolve; deprecated aliases for exploded buttons/kit names | ✅ |
| 16 | R106-A16 | **G14-B** Dart call-site migrate — all foundation importers; analyze clean; CI bans old paths after shim phase | ✅ |
| 17 | R106-A17 | **G14-C** Pack wire freeze — layout types keep working; forja-packs PR only if JSON must change | ✅ |
| 18 | R106-A18 | **G14-D** Evacuate parity — match details, schedule, VerticalMenu, sources, follow, packs, deeplink still work | ✅ |
| 19 | R106-A19 | **G14-E** QA Q1–Q12 green → shim death → delete `apps/forja/lib/shared/foundation/` | ⏭️ |
| 20 | R106-A20 | **G14-F** Docs/rules — migration guide, pack author note, design-system rules → package paths | ✅ |
| 21 | R106-A21 | **G14-G** Hard invariants — compile every PR; no silent pack break; no delete-before-wire | ✅ |
| 22 | R106-A22 | Stub tree deleted — `apps/forja/lib/shared/foundation/` gone; dart `rg` empty | ✅ |

---

## Acceptance (body evacuate — issue 271)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 23 | R106-A23 | KitShell body scroll/section chrome via CatalogBody / CatalogShell | ✅ |
| 24 | R106-A24 | CatalogList / SidePanelOverlay wired from kit_list_widget | ✅ |
| 25 | R106-A25 | Search page + single SearchFilters model in package | ✅ |
| 26 | R106-A26 | Details body composition via DetailsPageBlock / DetailsScreen slots | ✅ |
| 27 | R106-A27 | Vertical filters rail paint DS-first (LogoMenuRail); registry host | ✅ |

---

## Acceptance (deeper paint evacuate — issue 277)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 28 | R106-A28 | Search cards + filter lens painters in package; host thin mapper | ✅ |
| 29 | R106-A29 | KitSection thin CatalogSection mapper (< ~200 lines) | ✅ |
| 30 | R106-A30 | List grid/dense/empty chrome via CatalogList composers | ✅ |

---

## Acceptance (pack-product host law)

G11 (`R106-A12` / `R106-C07`) parked leftover app glue under `shared/host/**` so the DS package stayed design-only. That **folder brand is wrong** for Forja today: root is a **pack-product host** (generic only). Packs own product. Do not use this RFC to dump Live Sports / Lists / Search / Sources into `shared/host/`. See [091](091-[fixed]-live-sports-explode-host-to-packs.md) · [087](087-[fixed]-live-sports-pack-only.md) · [088](088-[fixed]-my-list-pack-only.md).

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 31 | R106-A31 | Docs law: `shared/host/` is **not** a product destination; no new catalog/live/lists/sources trees there | ✅ |
| 32 | R106-A32 | [Evacuate parity](../106-evacuate-parity.md) corrected — pack surfaces map to engine/kit/player; leftovers listed as app-only modules | ✅ |
| 33 | R106-A33 | A18 evacuate **wiring** closed; A19 visual QA stays ⏭️ and does **not** gate pack/kit/engine evolution | ✅ |

---

## Summary

Move the Forja design system from `apps/forja/lib/shared/foundation/` into [`packages/forja_foundation`](../../../packages/forja_foundation): tokens → theme → primitives → components → widgets → blocks, plus protocol/kit/platform/utils. One public widget per family (`Button`, `ButtonGroup`, `VerticalMenu`, …) with variants/sizes/slots.

**Product does not leave the package into a `shared/host/` silo.** Product lives in **packs** (`forja-packs`). The Flutter root stays generic (kit paint, engine runtime, player, shell, opaque registries). Leftover app-only modules that are not design-system (pack install UI, updater, keychain, watch-history store, search engine glue) may sit under today’s `shared/host/{packs,update,account,watch,search}/` paths until renamed — they are **not** a layer for hub/product trees.

**Part 1** builds the package (G0–G13). **Part 2** upgrades consumers (G14). Shim tree is deleted (A22). Visual QA Q1–Q12 remains unsigned (**A19 only**) — unsigned QA does not block product work.

### Goals

- Second app could depend on DS APIs without `apps/forja` internals
- Flat cinematic tokens/theme as `ThemeExtension`
- Button/ButtonGroup/VerticalMenu as the first family slice
- Zero-regression cutover via shims then migrate then delete
- Root stays pack-product host — generic only (R106-C09)

### Non-goals

- React / web design system
- Moving `packages/rust` or player engines into foundation
- Pack folder allowlists in Dart
- Editing `docs/backlog/`
- Recreating a product dump under `shared/host/` (supersedes G11 destination reading)

### Related

- Plan: `.cursor/plans/foundation_design_system_package_683fe89e.plan.md`
- [Evacuate parity (G14-D)](../106-evacuate-parity.md) · [Export inventory](../106-export-inventory.txt) · [Call-site inventory](../106-callsite-inventory.md) · [Invariants (G14-G)](../106-invariants.md)
- Package [MIGRATION.md](../../../packages/forja_foundation/MIGRATION.md) · [PACK_AUTHORS.md](../../../packages/forja_foundation/PACK_AUTHORS.md) · [QA matrix](../106-qa-matrix.md)
- [RFC-095](095-[fixed]-foundation-design-data-split.md) — design alone / data alone
- [RFC-085](085-[fixed]-catalog-kit-generic-only.md) — kit generic only
- [RFC-025](025-[fixed]-flat-cinematic-shell.md) — flat cinematic shell
- [RFC-091](091-[fixed]-live-sports-explode-host-to-packs.md) — deleted `shared/host/` product silo
