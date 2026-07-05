# Phase 3 — Delete Flutter

**Status:** Future  
**Gate:** [Phase 2 exit criteria](./02-kotlin-compose.md#exit-criteria) green on all target platforms

---

## Goal

Remove Flutter from the monorepo entirely. Compose is the only UI; Kotlin calls `libffi` directly.

---

## Exit criteria

- [ ] Compose app ships on all target platforms (Android, iOS, desktop subset per Phase 2 rollout)
- [ ] No production dependency on `dart:ffi` or Flutter plugins for engine paths
- [ ] CI green without Flutter jobs
- [ ] Monorepo docs updated (RFC-001 layout, README, melos)

---

## Deletion checklist

| ID | Task | Verify before delete |
|----|------|----------------------|
| P3-01 | Delete `apps/forja/` | Compose replaces all 19 tabs + player + settings |
| P3-02 | Delete `packages/rust/` | `forja_kotlin` covers all FFI |
| P3-03 | Delete superseded Dart packages | Each ported to Kotlin (`core`, `storage`, `api`, `streaming`, `webstreamr`, `scrapers`) |
| P3-04 | Remove `libtorrent_flutter` | B2 done + Compose torrent path tested |
| P3-05 | Remove Flutter CI | `.github/workflows/forja-macos.yml`, melos flutter scripts |
| P3-06 | Parity tests | Migrate fixtures to Rust-only goldens OR archive `packages/rust/test/` |
| P3-07 | Update monorepo docs | RFC-001, root README, melos.yaml |

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

- `melos` Flutter bootstrap scripts (`analyze`, `test` over Dart packages)
- `melos run rust:integration` (Flutter integration tests) → Kotlin/Compose smoke tests
- Dart parity tests in CI → optional archived job or Rust-only goldens

Keep:

- `melos run rust:test` (cargo + optionally archived Dart parity until P3-06)
- `melos run rust:build` / `rust:build:mobile` / `rust:release-check`

---

## Risk gates

Do **not** delete Flutter until:

1. Magnet → play works on mobile via Rust or approved bridge (P2-21)
2. IPTV import + Xtream browse smoke-tested on Compose
3. At least one webstreamr provider end-to-end on Compose
4. Settings persistence ported (`storage` → Kotlin)

---

## Related

- [Phase 2 — Kotlin Compose](./02-kotlin-compose.md)
- [Phase 1 — Rust engine](./01-rust-engine.md) (B2 tail)
- [RFC-001](../rfc/001-monorepo.md)
