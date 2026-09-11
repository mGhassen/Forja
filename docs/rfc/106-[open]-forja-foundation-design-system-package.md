# RFC-106: Forja foundation design system package

**Status:** open  
**Depends on:** [RFC-095](fixed/095-[fixed]-foundation-design-data-split.md) · [RFC-085](085-[partial]-catalog-kit-generic-only.md) · [RFC-025](fixed/025-[fixed]-flat-cinematic-shell.md)  
**Area:** `packages/forja_foundation`, `apps/forja`

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 8** components · **14 / 14** acceptance (Part 1) · **5 / 7** acceptance (Part 2) · **1** ⏭️ shim death |
| **Current slice** | Part 1 ✅ · exhaustive `MIGRATION.md` · call sites on package/shell (primitives = re-export stubs) · A16 ✅ analyze clean (CI ban waits G14-E) · A18 🔄 unsigned QA · **shim death waits Q1–Q12** |

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
| 8 | R106-C08 | Part 2 consumer upgrade — shims, migrate, QA, shim death | 🔄 |

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
| 18 | R106-A18 | **G14-D** Evacuate parity — match details, schedule, VerticalMenu, sources, follow, packs, deeplink still work | 🔄 |
| 19 | R106-A19 | **G14-E** QA Q1–Q12 green → shim death → delete `apps/forja/lib/shared/foundation/` | ⏭️ |
| 20 | R106-A20 | **G14-F** Docs/rules — migration guide, pack author note, design-system rules → package paths | ✅ |
| 21 | R106-A21 | **G14-G** Hard invariants — compile every PR; no silent pack break; no delete-before-wire | ✅ |

---

## Summary

Move the Forja design system from `apps/forja/lib/shared/foundation/` into [`packages/forja_foundation`](../../packages/forja_foundation): tokens → theme → primitives → components → widgets → blocks, plus protocol/kit/platform/utils. One public widget per family (`Button`, `ButtonGroup`, `VerticalMenu`, …) with variants/sizes/slots. Product domain leaves the package for host adapters.

**Part 1** builds the package (G0–G13). **Part 2** upgrades every consumer without loss (G14). Part 1 alone is not “done.” Shim death and deleting `shared/foundation/` wait for G14 QA.

### Goals

- Second app could depend on DS APIs without `apps/forja` internals
- Flat cinematic tokens/theme as `ThemeExtension`
- Button/ButtonGroup/VerticalMenu as the first family slice
- Zero-regression cutover via shims then migrate then delete

### Non-goals

- React / web design system
- Moving `packages/rust` or player engines into foundation
- Pack folder allowlists in Dart
- Editing `docs/backlog/`

### Related

- Plan: `.cursor/plans/foundation_design_system_package_683fe89e.plan.md`
- [Evacuate parity (G14-D)](106-evacuate-parity.md) · [Export inventory](106-export-inventory.txt) · [Call-site inventory](106-callsite-inventory.md) · [Invariants (G14-G)](106-invariants.md)
- Package [MIGRATION.md](../../packages/forja_foundation/MIGRATION.md) · [PACK_AUTHORS.md](../../packages/forja_foundation/PACK_AUTHORS.md) · [QA matrix](106-qa-matrix.md)
- [RFC-095](fixed/095-[fixed]-foundation-design-data-split.md) — design alone / data alone
- [RFC-085](085-[partial]-catalog-kit-generic-only.md) — kit generic only
- [RFC-025](fixed/025-[fixed]-flat-cinematic-shell.md) — flat cinematic shell
