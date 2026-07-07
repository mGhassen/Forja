# P3-03 — `packages/api` deleted; host relocation complete

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Phase:** [P3-03](../migration/fixed/03-[fixed]-engine-catalog.md)  
**Related:** [021 catalog vertical smoke](../021-[draft]-catalog-vertical-import-smoke-unverified.md)

---

## Summary

`packages/api` is **deleted**. Remaining Dart was relocated to `apps/forja` (playback, music, jellyfin) or `packages/rust` (`subtitle_api`). No `package:api/` imports remain in production code.

## Final batch (shipped)

| Change | Location |
|--------|----------|
| Playback barrel + debrid + site111477 + resolvers | `apps/forja/lib/shared/playback/` |
| Jackett / Prowlarr / link resolver / mega proxy | `apps/forja/lib/shared/playback/` |
| Music service + YouTube audio extractor | `apps/forja/lib/shared/audio/` |
| Jellyfin service | `apps/forja/lib/features/jellyfin/catalog/` |
| Subtitle API | `packages/rust/lib/src/catalog/subtitle_api.dart` |
| Package removed | ~~`packages/api/`~~; dropped from `apps/forja` + `packages/rust` pubspecs |
| FFI check script | `scripts/check_sync_ffi.sh` — no longer scans `packages/api` |

## Acceptance criteria (P3-03)

- [x] Relocate host-appropriate code to `apps/forja` / `packages/rust`.
- [x] Remove `packages/api` from workspace (melos `packages/**` no longer includes it).
- [x] `rg 'package:api/'` → zero outside docs/history.
- [x] Exit checklist **A1** (`packages/api` deleted) and **A3** (only `packages/rust` under `packages/`) — see [03-engine-catalog.md](../migration/fixed/03-[fixed]-engine-catalog.md).

**Not in scope (P3-04):** **A2** (all C1 catalog in `crates/*`) and **A4** (no Dart engine logic outside FFI) remain open — Dart HTTP/orchestration now lives under `apps/forja/lib/shared/playback/` and catalog verticals in `apps/forja`.

## Verify

```bash
test ! -d packages/api
rg 'package:api/' apps/forja packages/rust
cd apps/forja && dart analyze
```

## Symptom vs root

| Layer | State |
|-------|--------|
| **Symptom (this issue)** | Legacy `packages/api` package removed; imports rewired |
| **Root (still open)** | Dart engine HTTP in `forja` (debrid, site111477, jackett, …) and blocking `reqwest` in `anime-core` — port to `crates/*` per [ENGINE_BOUNDARY.md](../../ENGINE_BOUNDARY.md); async HTTP per [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
