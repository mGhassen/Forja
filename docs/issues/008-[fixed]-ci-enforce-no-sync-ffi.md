# 008 — CI must reject sync Rust FFI in app/api layers

**Priority:** P1  
**Severity:** High (regression prevention)  
**Status:** fixed (`scripts/check_sync_ffi.sh` + allowlist)  
**Area:** `scripts/`, `.github/workflows/`, `docs/issues/004-[open]-sync-ffi-ui-thread-audit.md`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Summary

The rule "no sync FFI on UI thread" exists in [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) and [RFC-009](../rfc/009-rust-ffi.md) but **nothing enforces it**. Every new `RustLib.instance.*` call is a potential UI freeze. Fixes in [001](001-[fixed]-webstreamr-blocks-ui.md) and IPTV do not prevent the next landmine.

## Solution (2026-07-06)

### `scripts/check_sync_ffi.sh`

Greps `RustLib.instance.` under `apps/forja/lib/` and `packages/api/lib/` (excluding `*_test.dart`). Fails CI if any match is not in the allowlist. Also flags stale allowlist entries (paths listed but no longer containing `RustLib.instance.`).

### Allowlist — `docs/issues/sync-ffi-allowlist.txt`

Explicit repo-relative paths with justification. Current entries:

| Path | Reason |
|------|--------|
| `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart` | `RustLib.instance` only inside `runRustIsolate()` callbacks |
| `apps/forja/lib/features/iptv/iptv/data/pastesh_decryptor.dart` | same |
| `apps/forja/lib/features/iptv/iptv/m3u/m3u_store.dart` | same |
| `apps/forja/lib/features/settings/settings_screen.dart` | instant/tiny FFI |
| `packages/api/lib/api/stremio_service.dart` | HTTP offloaded; JSON parse helpers CPU-only on small payloads |
| `packages/api/lib/playback/torrent_stream_service.dart` | short sync ops at startup/teardown |
| `packages/api/lib/playback/local_server_service.dart` | same |
| `packages/api/lib/playback/site111477_proxy.dart` | same |

`packages/rust/lib/src/isolate_runner.dart` is not allowlisted — it lives outside the scanned dirs and is the intended home for all long FFI wrappers.

### Policy

All HTTP, scrape, torrent-search, and multi-page resolve FFI **must** go through `isolate_runner.dart` typed wrappers. New direct `RustLib.instance.*` in app/api requires an allowlist entry with justification or the check fails.

### CI wiring

Registered in `melos.yaml` as `check-sync-ffi` → `../../scripts/check_sync_ffi.sh`.

## Acceptance

- [x] `scripts/check_sync_ffi.sh` in CI (via melos)
- [x] Allowlist minimal after [005](005-[fixed]-stremio-http-blocks-ui.md)–[007](007-[fixed]-torrent-search-blocks-ui.md) fixed
- [x] Documented in `.cursor/rules/rust-migration.mdc`
