# RFC-031: Source Engine middleware

**Status:** open  
**Depends on:** [RFC-030](030-[open]-playback-selection-engine.md)  
**Area:** `packages/rust/lib/src/playback/`, `apps/forja/lib/shared/playback/`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **8 / 8** acceptance (slice 1) · **4 / 4** acceptance (slice 2) · **1 / 9** acceptance (slice 3) |
| **Current slice** | In-player no silent failover; settings-baseline scoring still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R31-C01 | `SourceDomain` + `ProviderProfile` (domain-scoped priority) | ✅ |
| 2 | R31-C02 | `SourceEngine` order / filter / preferred pin | ✅ |
| 3 | R31-C03 | `PlaybackService` facade (`auto` \| provider id) | ✅ |

---

## Acceptance (slice 1 — movie/series + profiles)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R31-A01 | Profiles exclude cross-domain providers (Videoasy not in anime) | ✅ |
| 2 | R31-A02 | Auto orders by domain priority then settings order | ✅ |
| 3 | R31-A03 | Preferred provider ≠ auto → strict single-provider resolve | ✅ |
| 4 | R31-A04 | Details webstreaming uses `SourceEngine` for movie/series | ✅ |
| 5 | R31-A05 | Anime race uses anime-domain profile order | ✅ |
| 6 | R31-A06 | Feature doc describes Auto + domain engines | ✅ |
| 7 | R31-A07 | IPTV / torrent engines registered (stubs ok) | ✅ |
| 8 | R31-A08 | Asian Drama engine profile wired | ✅ |

---

## Acceptance (slice 2 — player Auto / pin)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 9 | R31-A09 | Full anime `defaultOrder` profiles in `ProviderProfiles` | ✅ |
| 10 | R31-A10 | Auto failover walks `SourceEngine.nextProviderIds` | ✅ |
| 11 | R31-A11 | Manual pin resolves via `PlaybackService` (strict) | ✅ |
| 12 | R31-A12 | Selecting Auto re-races domain providers | ✅ |

---

## Acceptance (slice 3 — unified scoring + resolve)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 13 | R31-A13 | Settings order is provider baseline; domain score adjusts at most ±2 ranks | ⬜ |
| 14 | R31-A14 | Anime main play path uses shared `PlaybackEngine` + Rust URL scoring | ⬜ |
| 15 | R31-A15 | Asian Drama uses shared pipeline (single `kisskh` provider, no bypass) | ⬜ |
| 16 | R31-A16 | Player Auto/failover passes settings order for all domains | ⬜ |
| 17 | R31-A17 | Settings scoring table shows per-type domain scores + effective preview | ⬜ |
| 18 | R31-A18 | Android TV fallback aligns with effective-order contract | ⬜ |
| 19 | R31-A19 | Single-source domain test: one resolver, empty failover chain | ⬜ |
| 20 | R31-A20 | Feature docs describe shared scoring table + unified pipeline | ⬜ |
| 21 | R31-A21 | In-player dead stream stops — no silent provider/source hop; user picks Sources | ✅ |

---

## Summary

Domain-scoped **Source Engines** sit between the UI and scrapers. The app asks for a playable source; it does not pick among Videoasy vs KissKH globally. Each engine owns its providers, priorities, and fallback. RFC-030 still owns URL/device scoring after candidates exist.

```
UI → PlaybackService → SourceEngine(domain) → scrapers → PlayableSource → player
```

Manual provider pick stays: `preferred = auto | <id>`. Strict manual = fail on that provider (current UX). Auto = score within the domain only.

## Non-goals

- Rewriting anime/drama player UIs in slice 1
- Soft fallback after manual fail (optional setting later)
- Merging IPTV portal UX into the movie provider menu

## Related

- [RFC-030](030-[open]-playback-selection-engine.md)
- [stream-providers](../features/sources/stream-providers.md)
