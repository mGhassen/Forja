# Phase 4 — Delete Flutter

**Status:** Future  
**Gate:** [Phase 3 exit criteria](./03-kotlin-compose.md#exit-criteria) green on all target platforms

---

## Goal

Remove Flutter from the monorepo entirely. Compose is the only UI; Kotlin calls `libforja_ffi` directly.

---

## Exit criteria

- [ ] Compose app ships on all target platforms (Android, iOS, desktop subset per Phase 3 rollout)
- [ ] No production dependency on `dart:ffi` or Flutter plugins
- [ ] CI green without Flutter jobs
- [ ] Monorepo docs updated (RFC-001 layout, README, melos)

---

## Deletion checklist

| ID | Task | Verify before delete |
|----|------|----------------------|
| P4-01 | Delete `apps/forja/` | Compose replaces all 19 tabs + player + settings |
| P4-02 | Delete `packages/forja_rust/` | `forja_kotlin` covers all FFI |
| P4-03 | Delete superseded Dart packages | Each ported to Kotlin |
| P4-04 | Remove Flutter CI | `.github/workflows/forja-macos.yml`, melos flutter scripts |
| P4-05 | Parity tests | Migrate fixtures to Rust-only goldens OR archive `packages/forja_rust/test/` |
| P4-06 | Update monorepo docs | RFC-001, root README, melos.yaml |

Note: `libtorrent_flutter` must already be gone (Phase 2).

---

## Keep permanently

| Path | Reason |
|------|--------|
| `crates/**` | Rust engine |
| `scripts/build_rust.sh` | Desktop FFI build |
| `scripts/build_rust_mobile.sh` | Mobile FFI build |
| `.github/workflows/rust.yml` | Rust CI |
| `packages/forja_kotlin/` | Kotlin FFI bridge |

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

## Risk gates

Do **not** delete Flutter until:

1. Magnet → play works on Compose (Rust librqbit from Phase 2)
2. IPTV import + Xtream browse smoke-tested on Compose
3. At least one webstreamr provider end-to-end on Compose
4. Settings persistence ported (`forja_storage` → Kotlin)

---

## Related

- [Phase 3 — Kotlin Compose](./03-kotlin-compose.md)
- [Phase 2 — Rust engine complete](./02-rust-engine-complete.md)
- [RFC-001](../rfc/001-monorepo.md)
