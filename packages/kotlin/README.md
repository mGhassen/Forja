# Kotlin FFI (Phase 2 POC)

UniFFI Kotlin bindings for the Rust engine. Consumed by Compose UI in Phase 3.

## Generate

```bash
./scripts/generate_kotlin_ffi.sh
```

Output: `generated/dev/forja/ffi/forja.kt` (package `dev.forja.ffi`, loads `libffi`).

## Source of truth

- UDL: `crates/ffi/src/forja.udl`
- C ABI (Dart/JNI): `crates/ffi/src/c_api.rs`
- Config: `crates/ffi/uniffi.toml`

## Phase 3

Wire into `apps/forja_compose/` Gradle — link prebuilt `libffi.so` / `.dylib` from `./scripts/build_rust_mobile.sh`.
