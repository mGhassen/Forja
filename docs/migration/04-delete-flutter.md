# Phase 4 — Delete Flutter

**Status:** Future (blocked on Phase 3)  
**Gate:** [Phase 3 exit criteria](./03-kotlin-compose.md#exit-criteria) green on all target platforms  
**Migration index:** [README.md](./README.md)  
**Spec:** [RFC-001](../rfc/001-monorepo.md)

---

## Status at a glance

**Goal:** delete Flutter from the monorepo. Compose is the only UI.

| | |
|--|--|
| **Progress** | **0 / 6 deletion tasks (0%)** |
| **Blocked by** | Phase 3 complete (RFC-011 parity on all target platforms) |

**Legend:** ✅ done · ⬜ not started

### Task tracker

#### ⬜ Deletion checklist (P4-01 → P4-06)

| ID | Delete | Verify first |
|----|--------|--------------|
| P4-01 | `apps/forja/` | Compose covers 19 tabs + player + settings |
| P4-02 | `packages/rust/` | `packages/kotlin` covers all FFI |
| P4-03 | *(verify only)* engine Dart packages gone since Phase 2 | `api`, `storage`, `core`, `scrapers`, `webstreamr`, `streaming` |
| P4-04 | Flutter CI jobs | `.github/workflows/forja-macos.yml`, melos flutter scripts |
| P4-05 | Dart parity tests | migrate to Rust goldens or archive |
| P4-06 | Update docs | RFC-001, README, melos.yaml |

#### ⬜ Risk gates — must pass before **any** delete

| Gate | Smoke test |
|------|------------|
| Magnet → play | Compose + Rust librqbit |
| IPTV | import + Xtream browse |
| Webstreamr | one provider end-to-end |
| Settings | persistence via `crates/storage` FFI |

#### ⬜ CI cleanup

| What | Action |
|------|--------|
| `melos run rust:integration` (Flutter) | → Compose smoke tests |
| Dart parity in CI | → Rust-only goldens |
| Keep | `melos run rust:test`, `rust:build`, `rust:build:mobile` |

### Exit checklist

| # | Criterion | |
|---|-----------|---|
| 1 | Compose ships Android + iOS + desktop subset | ⬜ |
| 2 | Zero production `dart:ffi` / Flutter plugins | ⬜ |
| 3 | CI green without Flutter jobs | ⬜ |
| 4 | Monorepo docs updated | ⬜ |

**0 / 4 exit criteria met.**

### Keep forever

`crates/**` · `scripts/build_rust*.sh` · `rust.yml` · **`packages/kotlin/`** (uniffi FFI)

### Must already be gone before Phase 4 (deleted in Phase 2)

These are engine — ported to `crates/*` and **deleted**, not carried to Phase 3/4:

`packages/api` · `packages/storage` · `packages/core` · `packages/scrapers` · `packages/webstreamr` · `packages/streaming`

If any still exist, Phase 2 is not complete.

---

## Deletion checklist

| ID | Task | Verify before delete |
|----|------|----------------------|
| P4-01 | Delete `apps/forja/` | Compose replaces all 19 tabs + player + settings |
| P4-02 | Delete `packages/rust/` (Dart FFI loader) | `packages/kotlin` covers all FFI |
| P4-03 | Verify engine Dart packages already deleted | Must be gone since Phase 2 — `api`, `storage`, `core`, `scrapers`, `webstreamr`, `streaming` |
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
