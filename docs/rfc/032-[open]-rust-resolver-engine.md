# RFC-032: Rust Resolver Engine

**Status:** open  
**Depends on:** [RFC-030](030-[open]-playback-selection-engine.md), [RFC-031](031-[open]-source-engine-middleware.md), [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md)  
**Area:** `crates/resolver-engine/`, `packages/rust/lib/src/playback/`, `apps/forja/lib/shared/playback/`

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** components · **6 / 6** acceptance (slice 1) · **6 / 9** acceptance (slice 2) |
| **Current slice** | Hardening — template embeds are one file each; videasy/template native ports open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R32-C01 | `crates/resolver-engine` crate (registry, orchestrator, health, scoring, cache, HTTP, cookies, headers) | ✅ |
| 2 | R32-C02 | `Provider` trait + one-file-per-plugin layout | ✅ |
| 3 | R32-C03 | `JobKind::ResolverEngineResolve` + `ResolverEngineContinue` FFI | ✅ |
| 4 | R32-C04 | Dart `ResolverEngineClient` + `PlaybackEngine` integration | ✅ |
| 5 | R32-C05 | `HostProviderAdapter` for C3/C4/C5 plugins | ✅ |
| 6 | R32-C06 | First-wave plugins (webstreamr, vidsrc, videasy-host, templates, 111477, nuvio) | ✅ |
| 7 | R32-C07 | v2 plugins (torrentio, stremio-addon, debrid, iptv, kisskh-host) | ✅ |
| 8 | R32-C08 | Delete `stream_provider_resolver.dart` | ✅ |

---

## Acceptance (slice 1 — core resolve path)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R32-A01 | `PlaybackService.resolve` routes movie/series through Resolver Engine job | ✅ |
| 2 | R32-A02 | Rust-native plugins return `PlayableSource` without Dart provider switches | ✅ |
| 3 | R32-A03 | Host-required plugins emit `awaiting_host`; `HostProviderAdapter` fulfills + continue | ✅ |
| 4 | R32-A04 | `ENGINE_BOUNDARY` D2/R6 amended — engine owns race | ✅ |
| 5 | R32-A05 | Provider health + resolve cache modules exist in Rust | ✅ |
| 6 | R32-A06 | Feature doc updated for provider-agnostic resolve | ✅ |

---

## Acceptance (slice 2 — hardening)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 7 | R32-A07 | `ProviderScoreMemory` persisted in Rust health store | ✅ |
| 8 | R32-A08 | Parallel in-flight race (configurable `maxInFlight`) in orchestrator | ✅ |
| 9 | R32-A09 | Videasy HTTP port to Rust-native `VideasyProvider` | ⬜ |
| 10 | R32-A10 | Template embed providers Rust-native (shrink host surface) | ⬜ |
| 11 | R32-A11 | Issue 018 manual parity re-run on new path | ⬜ |
| 12 | R32-A12 | Dart + Rust integration tests for host continue flow | ✅ |
| 13 | R32-A13 | Every `stream` template ID registered as `HostRequired` plugin (issue 039) | ✅ |
| 14 | R32-A14 | Host pause/resume one-by-one in score order (no parallel host sprint) | ✅ |
| 15 | R32-A15 | Template embed providers are one standalone plugin file each (issue 050); shared helper in `host_template.rs` (not under `plugins/`) | ✅ |

---

## Summary

Introduce **`crates/resolver-engine`** as a core Rust module (peer to `torrent-engine` and `iptv`). Flutter calls `PlaybackService.resolve()`; the engine owns provider ordering, race, scoring, cache, cookies, and headers. Each built-in provider is a **standalone plugin file** implementing `Provider::resolve`. Host-only extractors (WebView, WASM, Nuvio) use `HostProviderAdapter`.

## Non-goals

- Player decode (C6) stays Flutter
- Nuvio JS runtime in Rust (D3)

## Related

- [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md) — D2, R6
- [RFC-031](031-[open]-source-engine-middleware.md) — Dart `SourceEngine` ordering contract
- [RFC-030](030-[open]-playback-selection-engine.md) — `PlayableSource` + ranker
