# Kotlin FFI (deprecated)

**Scheduled deletion:** P3-00 in [Phase 3 — Catalog engine](../../docs/migration/03-engine-catalog.md).

UniFFI Kotlin bindings were a Phase 2 POC. Compose UI migration was cancelled — Flutter is the permanent host.

## Generate (until deleted)

```bash
./scripts/generate_kotlin_ffi.sh
```

Output: `generated/dev/forja/ffi/forja.kt` (package `dev.forja.ffi`, loads `libffi`).

## Source of truth

- UDL: `crates/ffi/src/forja.udl`
- C ABI (Dart): `crates/ffi/src/c_api.rs`
- Config: `crates/ffi/uniffi.toml`

Dart uses C ABI via `packages/rust` — not UniFFI.
