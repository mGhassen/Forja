# 250 — Home hub AUTH_REQUIRED: TMDB API key missing in release builds

**Priority:** P0  
**Severity:** Critical  
**Status:** fixed  
**Area:** `apps/forja` EngineService, `crates/engine` extract, CI Flutter `--dart-define`  
**Reported:** 2026-09-08 (Android TV 1.5.0)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I250-T01 | CI / release scripts: pass `--dart-define=TMDB_API_KEY` on every Flutter build | ✅ |
| 2 | I250-T02 | EngineJS extract: fill empty `config.apiKey` from Rust-baked `tmdb::API_KEY` | ✅ |
| 3 | I250-T03 | Host `runCatalog`: dart-define first, Rust FFI `tmdbApiKey()` fallback | ✅ |
| 4 | I250-T04 | Unit test: `with_tmdb_api_key` fills empty / keeps user key | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I250-A01 | Manual: Android TV Home opens without “TMDB API key missing” toast after rebuild | ⬜ |

---

## Summary

Home hub (`plugins/hubs/home/tmdb.js`) needs `config.apiKey`. Host was supposed to inject `String.fromEnvironment('TMDB_API_KEY')` (R70-A14). CI already set `TMDB_API_KEY` for **Rust** compile, but Flutter release builds never passed `--dart-define=TMDB_API_KEY=…`, so the Dart inject was always empty. Hub returned `AUTH_REQUIRED` → KitShell toasted the pack message.

Not a race. The key was never in the Flutter binary.

**Root fix:** dart-define in CI + Rust extract inject + Dart FFI fallback when dart-define is empty.
