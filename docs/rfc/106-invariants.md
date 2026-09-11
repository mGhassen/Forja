# RFC-106 hard invariants (G14-G)

These stay true for every Part 2 PR. Shim tree is already deleted (A22).
Q1–Q12 remains unsigned (A19). Plan source: Part 2 G14-G.

| # | Invariant |
|--:|-----------|
| 1 | **App compiles after every merged PR** — shims bridge gaps; no “broken until Part 2.” |
| 2 | **No pack JSON required change** unless a forja-packs PR landed first. |
| 3 | **No user-facing entry point removed** without a replacement path in the same PR. |
| 4 | **Shim tree is gone** (`shared/foundation/` deleted, A22). Do not restore it. Q1–Q12 remains unsigned (A19). |
| 5 | **Part 1 evacuate PRs include host adapter wiring** enough to satisfy (1) and (3). |

## Enforcement

| Check | Script / artifact |
|-------|-------------------|
| Zone A no `package:forja/` / Riverpod | [`scripts/check_foundation_import_zone.sh`](../../scripts/check_foundation_import_zone.sh) |
| Shim tree stays gone + no dart imports | [`scripts/check_foundation_shim_alive.sh`](../../scripts/check_foundation_shim_alive.sh) |
| Pack layout wire aliases | `apps/forja/test/kit_layout_wire_freeze_test.dart` (+ `kit_types_wire_freeze_test.dart`) |
| Call-site migrate progress | [`106-callsite-inventory.md`](106-callsite-inventory.md) |

**Forbidden:** recreating `shared/foundation/` or importing `package:forja/shared/foundation/`.
