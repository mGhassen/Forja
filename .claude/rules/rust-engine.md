---
paths:
  - "crates/**"
  - "packages/rust/**"
  - "scripts/build_rust*"
---

# Rust engine

Read first: `docs/ENGINE_BOUNDARY.md`, then `.cursor/rules/rust-migration.mdc` and `.cursor/rules/rust-engine-versioning.mdc`.

- Engine = `crates/*` (fetch + parse in Rust, Pattern B FFI). Host = pixels + platform (WebView, Nuvio JS, player, OAuth). No new engine logic in Dart.
- Engine semver is the workspace version in `crates/Cargo.toml`, mirrored in `packages/rust/pubspec.yaml`. Bump only via `./scripts/release_local.sh bump-engine patch|minor|major` (asks the user first — it is a release-admin action). Never set per-crate `version =`.
- Long FFI off the UI thread: `Isolate.run` / `packages/rust/lib/src/isolate_runner.dart`. `RustLib.instance.*` in app code must be in `docs/issues/sync-ffi-allowlist.txt`.
- macOS CLT: `source scripts/lib/macos_rust_sdk.sh` before raw `cargo` (SDK pin for aws-lc-sys).
- Tests: `cargo test --workspace`, `cargo test -p utils --test golden`, `cargo test -p iptv --test golden_m3u`, `cargo clippy --workspace`, then `cd packages/rust && flutter test` (parity). Out-of-scope verticals sit in `crates/archive/` and are not linked from `ffi`.
