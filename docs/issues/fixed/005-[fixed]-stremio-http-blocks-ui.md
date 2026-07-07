# 005 — Stremio addon HTTP blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Status:** fixed (2026-07-06) — `EngineWorkerPool` + async `stremio-core` ([015](015-[fixed]-rust-blocking-http-engine-debt.md))  
**Root fix:** [015](015-[fixed]-rust-blocking-http-engine-debt.md)  
**Area:** `packages/api/lib/api/stremio_service.dart`, `crates/stremio-core`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[fixed]-sync-ffi-ui-thread-audit.md)
## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 2** code · **0 / 1** manual QA |
| **Backlog** | [0.4.2](../backlog/done/0.4.2-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---



## Root cause (before fix)

```dart
final raw = RustLib.instance.stremioHttpGet(url, timeoutSecs: timeoutSecs);
```

Blocking HTTP in Rust. Dart `async` did not yield during the FFI call.

## Workaround (shipped — 2026-07-06)

Isolate offload — stops UI freeze but **does not fix** blocking HTTP in `crates/stremio-core`. Root fix: [015](015-[fixed]-rust-blocking-http-engine-debt.md).

1. `runStremioHttpGet` in `packages/rust/lib/src/isolate_runner.dart`.
2. `packages/api/lib/api/stremio_service.dart:111` → `await runStremioHttpGet(...)`.

JSON parse helpers (`parseStremioManifestJson`, etc.) stay on UI thread — allowlisted in `sync-ffi-allowlist.txt` for CPU-only parse, not HTTP.

**Verify:** `bash scripts/check_sync_ffi.sh` — no unallowlisted `stremioHttpGet` on main isolate path.

## Root fix (open)

Track in [015](015-[fixed]-rust-blocking-http-engine-debt.md): async HTTP in `crates/stremio-core`.

## If this file is deleted

Engine debt remains tracked in **[015](015-[fixed]-rust-blocking-http-engine-debt.md)**.

## Acceptance

- [x] `stremioHttpGet` never called on main isolate from production code
- [ ] Manual test: slow addon URL — spinner animates, back works
