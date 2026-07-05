# Forja Rust engine

Workspace crates consumed by Flutter via `packages/forja_rust` (FFI).

**Progress:** [docs/migration/rust-engine-progress.md](../docs/migration/rust-engine-progress.md)  
**Spec:** [docs/rfc/009-rust-ffi.md](../docs/rfc/009-rust-ffi.md)

## Build

```bash
./scripts/build_rust.sh
```

## Test

```bash
cd crates && cargo test --workspace
cd crates && cargo test -p forja-utils --test golden
cd crates && cargo test -p forja-iptv-core --test golden_m3u
cd packages/forja_rust && flutter test
```

## Crates

| Crate | Role |
|-------|------|
| `forja-ffi` | uniffi + C ABI entry point |
| `forja-utils` | episode matcher, torrent filter, unpacker, HLS, kisskh |
| `forja-stream-core` | provider URL templates |
| `forja-iptv-core` | M3U, Xtream, paste.sh crypto |
| `forja-stremio-core` | Stremio manifest/URL helpers |
| `forja-webstreamr` | vidsrc extractor + types |
| `forja-scrapers` | Knaben/TPB/Uindex HTML parsers |
| `forja-torrent` | torrent session (stub; libtorrent later) |
| `forja-proxy` | local HTTP proxy (axum) |
