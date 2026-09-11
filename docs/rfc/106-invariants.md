# RFC-106 hard invariants (G14-G)

These stay true for every Part 1 evacuate PR and every Part 2 migrate PR until
shim death (G14-E). Plan source: Part 2 G14-G.

| # | Invariant |
|--:|-----------|
| 1 | **App compiles after every merged PR** — shims bridge gaps; no “broken until Part 2.” |
| 2 | **No pack JSON required change** unless a forja-packs PR landed first. |
| 3 | **No user-facing entry point removed** without a replacement path in the same PR. |
| 4 | **Shim death is a separate PR** after QA Q1–Q12 (G14-E) — do not delete `apps/forja/lib/shared/foundation/` earlier. |
| 5 | **Part 1 evacuate PRs include host adapter wiring** enough to satisfy (1) and (3). |

## Enforcement

| Check | Script / artifact |
|-------|-------------------|
| Zone A no `package:forja/` / Riverpod | [`scripts/check_foundation_import_zone.sh`](../../scripts/check_foundation_import_zone.sh) |
| Required shim stubs still exist | [`scripts/check_foundation_shim_alive.sh`](../../scripts/check_foundation_shim_alive.sh) |
| Pack layout wire aliases | `apps/forja/test/kit_layout_wire_freeze_test.dart` (+ `kit_types_wire_freeze_test.dart`) |
| Call-site migrate progress | [`106-callsite-inventory.md`](106-callsite-inventory.md) |

**Forbidden until G14-E:** deleting `shared/foundation/`, removing `compat_exports.dart` / `ds_bridge.dart` / `foundation.dart` / `match_event.dart` stub / `protocol.dart` re-export while inventory still lists required shims.
