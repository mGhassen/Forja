# Phase 4 — Delete Flutter

**Status:** Future (blocked on Phase 3)  
**Gate:** [Phase 3 exit criteria](./03-kotlin-compose.md#exit-criteria) green on all target platforms  
**Migration index:** [README.md](./README.md)  
**Spec:** [RFC-001](../rfc/001-monorepo.md)

---

## Status at a glance

**Goal:** remove Flutter from the monorepo. Compose is the only UI; Kotlin calls `libforja_ffi` directly.

**Phase 4 not started.** Deletion checklist **0 / 6** · risk gates **0 / 4**.

### Three columns — read every table this way

| Column | Question |
|--------|----------|
| **Compose ready** | Kotlin app covers this capability on all target platforms? |
| **Deleted** | Flutter/Dart path removed from repo? |
| **CI/docs updated** | No broken references in workflows or README? |

**Done = ✅** when every row is ✅/✅/✅. Do not delete until the matching Compose flow is smoke-tested.

### Workstreams

| Workstream | Done | Target | Status |
|------------|-----:|-------:|--------|
| Deletion checklist (P4-0x) | 0 | 6 | app · forja_rust · Dart pkgs · CI · parity · docs |
| Risk gates | 0 | 4 | magnet · IPTV · webstreamr · settings |
| Melos / CI cleanup | 0 | 3 | flutter scripts · integration · parity in CI |

### Feature matrix

| Area | Compose ready | Deleted | CI/docs | Notes |
|------|:-------------:|:-------:|:-------:|-------|
| **P4-01 `apps/forja/`** | — | — | — | 19 tabs + player + settings |
| **P4-02 `packages/rust/`** | — | — | — | `packages/kotlin` must cover FFI |
| **P4-03 Dart packages** | — | — | — | each ported in Phase 3 |
| **P4-04 Flutter CI** | — | — | — | `forja-macos.yml` · melos flutter |
| **P4-05 Parity tests** | — | — | — | migrate to Rust goldens or archive |
| **P4-06 Monorepo docs** | — | — | — | RFC-001 · README · melos.yaml |

### Exit criteria

| Criterion | Status |
|-----------|--------|
| Compose ships on all target platforms | open |
| No production `dart:ffi` or Flutter plugins | open |
| CI green without Flutter jobs | open |
| Monorepo docs updated | open |

### Risk gates (must pass before any delete)

| Gate | Status |
|------|--------|
| Magnet → play on Compose (Rust librqbit) | open |
| IPTV import + Xtream browse on Compose | open |
| One webstreamr provider end-to-end on Compose | open |
| Settings persistence ported (`forja_storage` → Kotlin) | open |

### Keep permanently

| Path | Reason |
|------|--------|
| `crates/**` | Rust engine |
| `scripts/build_rust*.sh` | FFI builds |
| `.github/workflows/rust.yml` | Rust CI |
| `packages/forja_kotlin/` | Kotlin FFI bridge |

### Numbers

| Metric | Value |
|--------|-------|
| Exit criteria met | 0 / 4 |
| Deletion tasks done | 0 / 6 |
| Risk gates passed | 0 / 4 |
| Flutter apps remaining | 1 (`apps/forja`) |
| Dart FFI package remaining | 1 (`packages/rust`) |

### Quick health check

_Not applicable until Phase 3 parity sign-off._

```bash
# Pre-delete verification (when Compose exists):
# melos run rust:test                    # must stay green
# no flutter / dart:ffi in production deps
# gh workflow list | grep -i flutter     # should be empty post-P4-04
```

### Next work

Blocked until [Phase 3 P3-70 sign-off](./03-kotlin-compose.md#tasks). `libtorrent_flutter` must already be gone (Phase 2 ✅).

---

## Deletion checklist

| ID | Task | Verify before delete |
|----|------|----------------------|
| P4-01 | Delete `apps/forja/` | Compose replaces all 19 tabs + player + settings |
| P4-02 | Delete `packages/rust/` (Dart FFI loader) | `packages/kotlin` covers all FFI |
| P4-03 | Delete superseded Dart packages | Each ported to Kotlin |
| P4-04 | Remove Flutter CI | `.github/workflows/forja-macos.yml`, melos flutter scripts |
| P4-05 | Parity tests | Migrate fixtures to Rust-only goldens OR archive `packages/rust/test/parity/dart_baseline/` |
| P4-06 | Update monorepo docs | RFC-001, root README, melos.yaml |

Note: `libtorrent_flutter` must already be gone (Phase 2).

---

## Melos / CI impact

Remove or replace:

- `melos` Flutter bootstrap scripts
- `melos run rust:integration` (Flutter) → Kotlin/Compose smoke tests
- Dart parity tests in CI → Rust-only goldens (Phase 2 should have migrated most)

Keep:

- `melos run rust:test` (cargo)
- `melos run rust:build` / `rust:build:mobile` / `rust:release-check`

---

## Related

- [Phase 3 — Kotlin Compose](./03-kotlin-compose.md)
- [Phase 2 — Rust engine complete](./02-rust-engine-complete.md)
- [RFC-001](../rfc/001-monorepo.md)
