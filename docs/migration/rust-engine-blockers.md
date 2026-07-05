# Rust engine migration — blockers

**Last updated:** 2026-07-05  
**Progress:** [rust-engine-progress.md](./rust-engine-progress.md)  
**Spec:** [RFC-009](../rfc/009-rust-ffi.md)

Tracks what **blocks Step 9 cleanup** and what **must be managed** before deleting Dart engine code or shipping Rust-only.

---

## At a glance

| ID | Blocker | Severity | Blocks |
|----|---------|----------|--------|
| B1 | `use_rust_engine` / Rust-off mode | **critical** | Delete Dart fallbacks · drop `libtorrent_flutter` |
| B2 | `libtorrent_flutter` still in dependency tree | **high** | Step 9 completion · smaller APK · web build |
| B3 | Dart reference layer (`packages/forja_rust/lib/src/reference/`) | **high** | Full Dart duplicate removal (tied to B1) |
| B4 | No app `integration_test/` | **medium** | Production sign-off on librqbit · safe libtorrent drop |
| B5 | Incomplete golden fixtures (webstreamr) | **medium** | Confidence to delete any remaining parse duplicates |
| B6 | RFC-009 parity gaps | **medium** | “Full parity suite” acceptance checkbox |
| B7 | Rust engine desktop-only | **low** | Mobile using Rust · single code path on iOS/Android |
| B8 | Dylib load / dev ergonomics | **low** | Onboarding · CI app builds without manual `build_rust.sh` |
| B9 | Stale RFC-009 migration table | **low** | Doc confusion only |

**Not blockers** (by design): WebView extractors · webstreamr fetcher/registry · scraper HTTP · HLS `/hls-proxy` · WASM (v3.0).

---

## Dependency chain

```
B1 Rust-off mode kept
 ├── B3 reference/*.dart cannot be removed
 ├── B2 libtorrent_flutter required (fallback + engine-off)
 └── Step 9 stalls at "consolidated fallbacks", not deletion

B4 no integration tests
 └── B2 cannot be closed with confidence (librqbit prod stability)

B5 + B6 incomplete test coverage
 └── harder to justify B1 removal (no Rust-off safety net)
```

**Unlock order (recommended):**

1. B5 + B6 — close test gaps  
2. B4 — add smoke `integration_test/` (torrent · IPTV · one webstreamr host)  
3. Ship with Rust default on; monitor librqbit in production  
4. **Decision on B1** — drop Developer toggle / Rust-off mode  
5. B2 + B3 — remove `libtorrent_flutter` and inline reference imports  

---

## Blocker details

### B1 — Rust-off mode (`use_rust_engine`)

| | |
|--|--|
| **What** | Settings → Developer toggle + `SettingsService.getUseRustEngine()` (default `true`) |
| **Why it blocks** | Every call site uses `*Backend` hook or `ForjaEngine.isReady` with Dart reference fallback |
| **Files** | `packages/forja_storage/lib/src/settings_service.dart` · `apps/forja/lib/app/bootstrap.dart` · `packages/forja_rust/lib/src/facade.dart` |
| **Manage** | Decide policy: keep for debugging forever vs. remove after N releases of stable Rust |
| **Unblocks** | Deleting `reference/*.dart` · removing `provider_fallback_urls.dart` · making Rust mandatory on desktop |

---

### B2 — `libtorrent_flutter` dependency

| | |
|--|--|
| **What** | Native torrent engine still linked in `apps/forja`, `forja_streaming`, `forja_api` |
| **Why it blocks** | `TorrentStreamService.start()` falls back to libtorrent when Rust port is 0 or `TorrentEngineBackend` unset; `applyConnectionsLimit` only touches libtorrent session |
| **Files** | `packages/forja_streaming/lib/src/torrent_stream_service.dart` · `apps/forja/pubspec.yaml` |
| **Manage** | Dogfood librqbit on desktop; log fallback rate; port connection-limit config to Rust or drop feature |
| **Unblocks** | Step 9 checkbox “Drop libtorrent_flutter”; RFC-010/014 web builds without native torrent |

---

### B3 — Dart reference layer

| | |
|--|--|
| **What** | 10 files under `packages/forja_rust/lib/src/reference/` used as fallbacks + parity baselines |
| **Why it blocks** | Production packages import them directly (`stremio_service.dart`, scrapers, `ForjaEngine` facade) — not dead code |
| **Files** | `m3u_dart_parser.dart` · `iptv_dart_parse.dart` · `pastesh_decrypt_dart.dart` · `stremio_dart_parse.dart` · `scrapers_dart_parse.dart` · `episode_matcher_dart.dart` · `hls_dart_parse.dart` · `js_unpacker_dart.dart` · `kisskh_decrypt_dart.dart` · `torrent_filter_dart.dart` |
| **Manage** | Keep until B1 resolved; parity tests must keep working against these |
| **Unblocks** | Step 9 “delete Dart duplicates” — engine code lives only in Rust + test fixtures |

---

### B4 — No integration tests

| | |
|--|--|
| **What** | CI runs Rust unit + Dart parity only; app smoke is manual |
| **Why it blocks** | Cannot gate libtorrent removal or Rust-only boot on real device flows |
| **Files** | `docs/migration/rust-engine-progress.md` CI matrix — `integration_test/` optional |
| **Manage** | Add `apps/forja/integration_test/` — boot · M3U import · magnet play · one stream provider |
| **Unblocks** | B2 production sign-off · safe B1 policy change |

---

### B5 — Incomplete webstreamr golden fixtures

| | |
|--|--|
| **What** | `crates/forja-webstreamr/tests/golden_extractors.rs` — 20 golden tests, 23 extractors |
| **Missing** | `kinoger` · `lulustream` · `fastream` (and full `filelions` / `voe` stream paths if distinct from redirect tests) |
| **Why it blocks** | Step 9 open item; regressions on unwired golden hosts |
| **Manage** | Capture HTML fixtures from prod failures; add one golden per missing extractor |
| **Unblocks** | Step 9 checkbox; confidence deleting any stray Dart parse copies |

---

### B6 — RFC-009 parity gaps

| | |
|--|--|
| **What** | Acceptance still open: “Full parity suite (all episode patterns, all M3U edge cases)” |
| **Why it blocks** | Formal migration sign-off per RFC |
| **Files** | `docs/rfc/009-rust-ffi.md` · `packages/forja_rust/test/parity/` |
| **Manage** | Audit episode_matcher + m3u parity vs `crates/*/tests/fixtures/`; extend tests |
| **Unblocks** | RFC-009 acceptance · stronger case for B1 removal |

---

### B7 — Rust engine desktop-only

| | |
|--|--|
| **What** | `ForjaEngine.init()` returns early on iOS/Android — mobile always Dart engine |
| **Why it blocks** | No mobile Rust dylib build pipeline; parity only on desktop CI |
| **Files** | `packages/forja_rust/lib/src/facade.dart` · `scripts/build_rust.sh` (macOS/Linux/Windows only) |
| **Manage** | Explicit non-goal for v1.0 engine phase unless mobile FFI is scoped |
| **Unblocks** | Nothing for Step 9 on desktop; separate project if mobile Rust wanted |

---

### B8 — Dylib load / dev ergonomics

| | |
|--|--|
| **What** | Dev must run `./scripts/build_rust.sh` or set `FORJA_RUST_LIB`; otherwise boot log shows Dart fallback |
| **Why it blocks** | False negatives in manual testing; new contributors think Rust is broken |
| **Files** | `packages/forja_rust/lib/src/library_path.dart` · `apps/forja/macos/copy_rust_dylib.sh` |
| **Manage** | Document in README; consider `melos` pre-run hook or CI artifact for app builds |
| **Unblocks** | Reliable manual QA for B4/B2 |

---

### B9 — Stale RFC-009 doc

| | |
|--|--|
| **What** | RFC migration table still says “1 extractor”, “not wired”, “stubs only” |
| **Why it blocks** | Planning confusion only |
| **Manage** | Sync RFC table + acceptance with `rust-engine-progress.md` when touching docs |
| **Unblocks** | Nothing runtime |

---

## Step 9 — open work mapped to blockers

| Step 9 item | Blocker(s) |
|-------------|------------|
| Drop `libtorrent_flutter` | B1 · B2 · B4 |
| Golden fixtures for every extractor | B5 |
| (implicit) delete `reference/*.dart` | B1 · B3 · B6 |

Completed Step 9 items (reference consolidation, dead file removal) do **not** remove blockers — they organized fallbacks, not deleted them.

---

## Explicit non-blockers

Do **not** track these as migration blockers:

| Item | Reason |
|------|--------|
| `forja_adapters/` WebView package | Never existed; WebView stays in app per RFC-009 |
| Webstreamr fetcher / registry / page HTTP | Orchestration stays Dart (same as scraper HTTP) |
| HLS `/hls-proxy` | Out of Rust scope; shelf rewrite in Dart |
| WASM / web client | RFC-014 v3.0 |
| KMP / Compose | Out of scope |

---

## Updating this doc

When a blocker is resolved or a new one appears:

1. Update this file (ID, severity, blocks).
2. Update [rust-engine-progress.md](./rust-engine-progress.md) Step 9 checkboxes.
3. Update [RFC-009](../rfc/009-rust-ffi.md) if acceptance affected.

See `.cursor/rules/rust-migration.mdc`.
