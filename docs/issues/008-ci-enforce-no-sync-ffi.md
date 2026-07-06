# 008 — CI must reject sync Rust FFI in app/api layers

**Priority:** P1  
**Severity:** High (regression prevention)  
**Status:** open  
**Area:** `scripts/`, `.github/workflows/`, `docs/issues/004-sync-ffi-ui-thread-audit.md`  
**Reported:** 2026-07-06  
**Parent:** [004](004-sync-ffi-ui-thread-audit.md)

## Summary

The rule "no sync FFI on UI thread" exists in [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) and [RFC-009](../rfc/009-rust-ffi.md) but **nothing enforces it**. Every new `RustLib.instance.*` call is a potential UI freeze. Fixes in [001](001-webstreamr-blocks-ui.md) and IPTV do not prevent the next landmine.

## Proposed enforcement

### CI grep script

Fail if `RustLib.instance.` appears under:
- `apps/forja/lib/`
- `packages/api/lib/`

**Except** allowlist:
- `packages/rust/lib/src/isolate_runner.dart` (wrappers may reference FFI inside `runRustIsolate` callbacks)
- `**/test/**`
- `docs/issues/sync-ffi-allowlist.txt` (explicit exceptions with justification)

### Policy

All HTTP, scrape, torrent-search, and multi-page resolve FFI **must** go through `isolate_runner.dart` typed wrappers. Direct `RustLib.instance.httpGetJson` forbidden outside bridge.

## Acceptance

- [ ] `scripts/check_sync_ffi.sh` (or equivalent) in CI
- [ ] Allowlist empty or minimal after [005](005-stremio-http-blocks-ui.md)–[007](007-torrent-search-blocks-ui.md) fixed
- [ ] Documented in `.cursor/rules/rust-migration.mdc`
