---
name: forja-rust-engine
description: >-
  Rust engine workflow for Forja: build/test commands, porting a Dart engine
  slice to crates/*, Pattern B FFI, parity tests, and the engine version bump
  policy. Use when touching crates/, packages/rust, FFI symbols, libffi build
  scripts, or when the user mentions engine, FFI, cargo, port to Rust, bump
  engine.
argument-hint: "[port <dart path> | ffi <symbol> | test | build]"
---

# /forja-rust-engine $ARGUMENTS

Engine version (workspace) and bridge label must match:

!`awk '/^\[workspace.package\]/{f=1} f && /^version/{print "crates/Cargo.toml: " $3; exit}' crates/Cargo.toml; grep -m1 '^version:' packages/rust/pubspec.yaml | sed 's/^/packages\/rust\/pubspec.yaml: /'`

Read `docs/ENGINE_BOUNDARY.md`, `.cursor/rules/rust-migration.mdc`, `.cursor/rules/rust-engine-versioning.mdc` first.

## Commands

```bash
source scripts/lib/macos_rust_sdk.sh                       # macOS CLT SDK pin (aws-lc-sys)
cd crates && cargo fmt --all && cargo clippy --workspace
cargo test --workspace && cargo test -p utils --test golden && cargo test -p iptv --test golden_m3u
./scripts/build_rust.sh                                    # desktop libffi → boot log "Rust engine v<version>"
./scripts/build_rust_mobile.sh android|ios|all             # mobile (ask first: slow, needs NDK/Xcode)
cd packages/rust && flutter test                           # Dart parity
cd apps/forja && flutter test test/engine_smoke_test.dart  # app smoke
```

## Port checklist (Dart → Rust)

1. Read the Dart engine source you are replacing.
2. Implement in `crates/<name>/` with unit + golden tests.
3. Expose in `crates/ffi` — **fetch + parse in Rust** (Pattern B). No `*_html_json`.
4. Wire `apps/forja` to `ForjaEngine.*`; long calls via `Isolate.run` / `isolate_runner.dart`.
5. **Delete the Dart slice** (files, pubspec deps, imports). A Dart wrapper that calls Rust but keeps the Dart is not a port.
6. Parity test in `packages/rust/test/parity/`.
7. Update the migration/issue doc rows (append-only).
8. Rebuild and run the command list above.

## Version bump

Trigger: patch = behavior fix on existing FFI · minor = new FFI/capability · major = breaking symbols. None for docs, Dart-only glue, host-only Dart.

`./scripts/release_local.sh bump-engine patch|minor|major` edits `crates/Cargo.toml`, `packages/rust/pubspec.yaml`, and the rule's "Current engine version" line together. It is a release-admin action: propose it, run it only when the user says so, never hand-edit one of the three.

User-visible engine changes get a changelog bullet under **Sources**, **Player**, or **Live & IPTV** — never an "Engine" group.