# 271 — Catalog body evacuate into forja_foundation

**Priority:** P1  
**Severity:** Medium  
**Status:** open  
**Area:** `packages/forja_foundation`, `apps/forja/lib/shared/shell`, `apps/forja/lib/shared/player`  
**Reported:** 2026-09-11  
**Related:** [RFC-106](../rfc/106-[open]-forja-foundation-design-system-package.md) · plan referred to issue 270 (number taken by live-providers fix)

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **7 / 8** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I271-T01 | Slice 1 — KitShell body → CatalogShell / CatalogBody / mood composers | ✅ |
| 2 | I271-T02 | Slice 2 — wire CatalogList / SidePanelOverlay in kit_list_widget | ✅ |
| 3 | I271-T03 | Slice 3 — KitSearchPage / filters → CatalogSearch* ; dedupe SearchFilters | ✅ |
| 4 | I271-T04 | Slice 4 — DetailsPageBlock / DetailsScreen body composition | ✅ |
| 5 | I271-T05 | Slice 5 — vertical_filters_rail paint → LogoMenuRail; registry KEEP | ✅ |
| 6 | I271-T06 | Slice 6 — strip TmdbApi art CDN rewrite from player chrome | ✅ |
| 7 | I271-T07 | Same-turn MIGRATION.md dump rows per slice | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I271-A01 | KitShell no longer builds CustomScrollView section chrome inline | ✅ |
| 2 | I271-A02 | `CatalogList(` used in kit_list_widget; panel split via DS | ✅ |
| 3 | I271-A03 | One SearchFilters model; KitSearchPage mapper around CatalogSearchPage | ✅ |
| 4 | I271-A04 | Details body composition mostly DS slots / DetailsPageBlock | ✅ |
| 5 | I271-A05 | No duplicate vertical menu chrome outside LogoMenuRail | ✅ |
| 6 | I271-A06 | Player art paths use absolute/pack URLs (no TmdbApi CDN rewrite) | ✅ |
| 7 | I271-A07 | Zone check + analyze clean on touched paths | ✅ |
| 8 | I271-A08 | User Q1–Q12 after slices 1–5 — agent does not flip R106-A18 | ⬜ |

---

## Summary

Prior dump work landed protocol, pack logos, glue deletes, and Zone A slots. Fat host painters (`kit_shell`, `kit_list_widget`, search, details) still own UI. Explode real paint into `forja_foundation`; host keeps MetaRuntime / Riverpod / TV only.

**Hard rules:** Zone A no `package:forja/` / Riverpod / `TmdbApi` / `Movie`. Import the file, never gallery barrel. No `shared/kit/` or `shared/foundation/`. Do not flip RFC-106 A18.

**Slices 1–6 code:** landed. **A08 / R106-A18:** run [106-qa-matrix.md](../rfc/106-qa-matrix.md) Q1–Q12 yourself, then flip A18 — agent will not.

## Root cause

Slot shells landed without finishing body evacuate — foundation composers stay thin while host files remain 1k–2k line painters.

## Fix approach

One slice at a time: MOVE/WIRE paint into package; KEEP MetaRuntime/Riverpod/TV on host; update MIGRATION.md same turn.
