# RFC-030: Playback selection engine

**Status:** open  
**Version:** v1.0.2  
**Depends on:** [ENGINE_BOUNDARY.md](../ENGINE_BOUNDARY.md), [RFC-004](004-[partial]-provider-registry.md), [RFC-009](fixed/009-[fixed]-rust-ffi.md)  
**Area:** `crates/stream-core/`, `packages/rust/lib/src/playback/`, `apps/forja/lib/shared/playback/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **14 / 16** acceptance (slice 1–2) · **0 / 8** slice 3 |
| **Current slice** | Device cap + recovery + resume unify shipped |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R30-C01 | `PlayableSource` canonical model (Rust + Dart) | ✅ |
| 2 | R30-C02 | `DevicePlaybackCapabilities` host probe + profile JSON | ✅ |
| 3 | R30-C03 | Rust stream scorer + ranker (`stream-core::select`) | ✅ |
| 4 | R30-C04 | `PlaybackEngine` orchestrator (normalize, rank, parallel resolve) | ✅ |

---

## Acceptance (slice 1 — model + TMDB)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R30-A01 | `PlayableSource` serde round-trip Rust ↔ Dart | ✅ |
| 2 | R30-A02 | Legacy `StreamSource` adapter infers codec/resolution from URL | ✅ |
| 3 | R30-A03 | Scorer ranks H264 1080p above HEVC 4K on constrained profile | ✅ |
| 4 | R30-A04 | `StreamProviderResolver` emits `PlayableSource` list | ✅ |
| 5 | R30-A05 | `dedupeStreamSources` delegates to engine rank when profile available | ✅ |
| 6 | R30-A06 | Parallel webstreaming resolve races providers (cap 3) | ✅ |
| 7 | R30-A07 | Player receives pre-ranked candidates; provider id not required for open | ✅ |
| 8 | R30-A08 | Rust unit tests for score + normalize | ✅ |

---

## Acceptance (slice 2 — device + recovery)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 9 | R30-A09 | Android MediaCodec probe populates HEVC/AV1/HDR flags | ✅ |
| 10 | R30-A10 | Settings max-quality cap feeds scorer | ✅ |
| 11 | R30-A11 | VOD player hw-decode → software fallback (IPTV pattern) | ✅ |
| 12 | R30-A12 | Audio vs video decoder errors classified separately | ✅ |
| 13 | R30-A13 | Failed URL blocklist across re-resolve | ✅ |
| 14 | R30-A14 | Android TV constrained profile wired to `PlaybackProfile` | ✅ |

---

## Acceptance (slice 3 — all domains)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 15 | R30-A15 | Anime resolver adapter → `PlayableSource` | ✅ |
| 16 | R30-A16 | KissKH / Arabic adapters → `PlayableSource` | ✅ |
| 17 | R30-A17 | Stremio / torrent adapters → `PlayableSource` | ✅ |
| 18 | R30-A18 | Episode switch uses `PlaybackEngine` | ✅ |
| 19 | R30-A19 | Player strips provider-specific branches (proxy/embed via flags) | ✅ |
| 20 | R30-A20 | Feature doc + backlog rows updated | ✅ |

---

## Summary

Unify all stream providers behind a canonical `PlayableSource` model. Device capabilities and a Rust scoring function pick the best compatible stream. The built-in player (media_kit / ExoPlayer per RFC-029) opens ranked candidates and recovers on failure without knowing which provider produced the URL.

## Problem

- Fragmented intermediate types per content domain
- URL-string heuristics for quality (`hevc` in path)
- Sequential provider try; no device-aware selection
- VOD player lacks IPTV-grade decoder recovery

## Goals

- Provider-agnostic playback contract at the player boundary
- Score-based selection with device capability input
- Automatic fallback: next candidate → software decode → re-resolve → next provider
- Rust owns scoring/normalization; host owns probe + player recovery

## Non-goals

- Replacing WebView/Nuvio/WASM extractors (stay on host per ENGINE_BOUNDARY C3–C5)
- External player (VLC/MX) fallback chain — documented limitation
- Perfect codec metadata from every extractor on day one — infer + enrich later

## Contracts

| Contract | Location |
|----------|----------|
| `PlayableSource` schema | `crates/stream-core/src/playable.rs` |
| Rank API | `playback_rank_sources_json` FFI |
| Orchestrator | `packages/rust/lib/src/playback/playback_engine.dart` |
| Recovery | `apps/forja/lib/shared/player/player/playback_recovery.dart` |

## Related

- [Issue 033](../issues/033-[open]-vod-decoder-recovery.md) — decoder recovery tracking
- [RFC-029](029-[open]-dual-built-in-playback-engines.md) — ExoPlayer + MediaKit
- [stream-providers feature](../features/sources/stream-providers.md)
