# librqbit-dualstack-sockets (vendored patch)

Upstream 0.7.0 treats iOS like Linux and calls `Socket::bind_device`, which does not exist on iOS. Apple platforms need `bind_device_by_index_v4` / `bind_device_by_index_v6`.

**Patch:** `src/bind_device.rs` — `#[cfg(any(target_os = "macos", target_os = "ios"))]`

Wired via `[patch.crates-io]` in `crates/Cargo.toml`. Remove when upstream releases a fix.
