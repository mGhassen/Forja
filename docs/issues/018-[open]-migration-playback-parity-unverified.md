# 018 — Wave 1 playback parity vs main unverified

**Priority:** P1  
**Severity:** High  
**Status:** open  
**Area:** `feat/rust-migratiom` vs `main`, `crates/*`, `packages/api/lib/playback/`, `apps/forja/lib/features/home/`, player  
**Reported:** 2026-07-07  
**Audit:** [migration parity audit](../../.cursor/plans/migration_parity_audit_0743c02b.plan.md)

## Summary

Phase 2 marks **41/41 playback tasks ✅** ([02-rust-engine-complete](../migration/02-rust-engine-complete.md)), but **functional equivalence with `main` is not proven**. Legacy Dart engine packages (`forja_streaming`, `forja_webstreamr`, `forja_scrapers`, `forja_storage`, `forja_core`) are deleted on the migration branch; behavior now lives in `crates/*` + thin Dart glue. No side-by-side comparison has been run on the same titles/network.

This is the parent issue for “did we forget something or break playback like WebStreamr losing the list?” ([017](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md) was one instance; others may remain undiscovered).

## What is at risk

| Flow | main engine | branch engine | Parity status |
|------|-------------|---------------|---------------|
| WebStreamr resolve | Dart `forja_webstreamr` | `crates/webstreamr` + `WebStreamrService` | Code fixes shipped [017](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md); **live count vs main unverified** |
| Builtin torrent search | Dart scrapers (Knaben/TPB/Uindex) | `crates/scrapers` | Golden tests only; **count vs main unverified** |
| Torrent filter/sort | Dart `TorrentFilter` | `Engine.filterTorrents` / `sortTorrents` | Parity tests exist; **E2E unverified** |
| Stremio streams | Dart HTTP + Rust parse | `runStremioHttpGet` + Rust parse | **Unverified** |
| Vidsrc resolve | Dart + Rust mix | `runResolveVidsrcEmbedJson` | **Unverified** |
| Provider race (streaming) | `streaming_details_screen` | Same screen, async jobs | **Unverified** |
| Player auto-fallback / sources list | Player screens | + gen-token cancel | **Unverified** |
| Resume from home (WebStreamr) | `home_screen` | Same path via Rust | **Unverified** |
| Magnet playback | libtorrent → librqbit | librqbit only | **Intentional engine swap** (P2-21); playback path needs smoke |
| IPTV probe / M3U | Partial Rust | More Rust FFI | **Unverified** |

Catalog verticals (`anime`, `manga`, `arabic`, etc.) are rename-only (`forja_api` → `api`) — tracked separately in [021](021-[open]-catalog-vertical-import-smoke-unverified.md).

## Root cause (why this issue exists)

1. Migration exit gate ([02-rust-engine-complete](../migration/02-rust-engine-complete.md) T8) relied on Rust goldens + limited smoke, not systematic main-vs-branch comparison.
2. [009](fixed/009-[fixed]-post-migration-resilience-audit.md) shipped cancel UX in code but **manual device QA was not run** for most checklist rows.
3. First parity regression (WebStreamr partial lists) was found in production QA, not CI — same class of bug may exist on other migrated paths.

## Verification matrix (must run before claiming parity)

Build **main** and **branch** on the same machine/network. Compare counts/URLs/UX — not just “it plays”.

| # | Flow | Test input | Pass criteria |
|---|------|------------|---------------|
| 1 | WebStreamr movie | Enola Holmes 3 `tt32278481` | ≥10 streams; HDHub4u 2160p/1080p; count matches main ±0 |
| 2 | WebStreamr TV | Known series S01E01 | Stream count matches main |
| 3 | WebStreamr cancel | Resolve → Cancel → retry | Second resolve non-empty; no hang |
| 4 | Torrent search | Same movie title | Top results / count match main |
| 5 | Stremio addon | Torrentio on same title | Same streams after `PlaybackProfile` filter |
| 6 | Vidsrc | Known embed title | Playable URL matches main |
| 7 | Provider race | Streaming mode auto-probe | First working provider same as main |
| 8 | Player sources | Single-source WebStreamr | `video_library` visible; list not empty |
| 9 | Resume | Home continue row | Same provider + URL as main |
| 10 | Magnet E2E | Test magnet | Playback starts (desktop; mobile if available) |

Automated gate (prerequisite):

```bash
./scripts/build_rust.sh
cd crates && cargo test --workspace
cd packages/rust && flutter test test/parity/
./scripts/check_sync_ffi.sh
```

## Child issues

| # | Topic |
|---|-------|
| [019](019-[open]-webstreamr-enginejobs-e2e-test-gap.md) | Live test bypasses `EngineJobs` app path |
| [020](020-[open]-cancel-gen-token-discard-unverified.md) | Gen-token may discard valid results |
| [021](021-[open]-catalog-vertical-import-smoke-unverified.md) | 14 verticals rename-only, no smoke |
| [022](022-[open]-playback-widget-integration-tests.md) | No widget tests with mocked slow FFI |
| [002](002-[open]-torrent-disk-cache-not-cleaned.md) | Torrent disk cache (pre-existing, not parity) |

## Acceptance

- [ ] Side-by-side matrix rows 1–10 executed; results recorded (pass/fail per row)
- [ ] Any mismatch filed as child bug issue or linked to existing fix
- [ ] Branch can be described as “playback parity with main verified” only when matrix passes

## If this file is deleted

Parity work is tracked in child issues [019](019-[open]-webstreamr-enginejobs-e2e-test-gap.md)–[022](022-[open]-playback-widget-integration-tests.md) and migration audit plan.
