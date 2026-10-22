---
paths:
  - "scripts/**"
  - ".github/**"
  - "melos.yaml"
---

# Scripts and CI

All GitHub workflows are `workflow_dispatch` only (manual). `rust.yml` runs cargo tests + clippy, Dart parity, engine smoke, and the boundary checks; `build.yml` / `release.yml` build installers and need repo secrets (TMDB, Supabase, R2, FORJA_WEB_URL).

Boundary scripts an agent may run freely: `scripts/check_sync_ffi.sh`, `check_tv_shell_boundary.sh`, `check_foundation_import_zone.sh`, `check_foundation_shim_alive.sh`, `check_rust_mobile_artifacts.sh`. They need `rg` on PATH — on this machine `rg` is only a zsh function, so run them from zsh or put Claude Code's vendored ripgrep on PATH first.

Known drift (2026-10-20): `check_foundation_import_zone.sh` expects `primitives/` and `theme/` zone dirs that no longer exist in `packages/forja_foundation/lib`; `check_sync_ffi.sh` reports two stale allowlist entries. Both would fail CI as-is.

Human-only (ask before running): `release_local.sh`, `release_ci.sh`, `bump_version.sh`, `changelog_freeze.sh`, `upload_release_to_r2*`, packaging scripts. Version and codename are release-admin decisions.
