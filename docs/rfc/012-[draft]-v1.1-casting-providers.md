# RFC-012: v1.1 — Casting + expanded providers

**Version:** v1.1  
**Status:** draft  
**Target version:** [1.0.1](../backlog/1.0.1-[draft].md) (slipped from [1.0.0](done/1.0.0-[done].md))  
**Depends on:** RFC-011 (v1.0)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 8** acceptance (v1.1 bundle) · child RFCs: [003](003-[partial]-player-overlay.md) 4/6·0/4, [004](004-[partial]-provider-registry.md) 3/3·0/3, [005](005-[partial]-casting.md) 0/1·0/4 |
| **Current slice** | v1.1 — overlay + providers + casting bundle |
| **Backlog** | [1.0.1](../backlog/1.0.1-[draft].md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.1 bundle)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R12-A01 | Server grid visible; switch provider mid-playback | ⬜ |
| 2 | R12-A02 | Active provider highlighted | ⬜ |
| 3 | R12-A03 | ~15+ providers in registry; toggles in Settings | ⬜ |
| 4 | R12-A04 | AirPlay macOS + iOS for VOD | ⬜ |
| 5 | R12-A05 | Chromecast Android + iOS for VOD | ⬜ |
| 6 | R12-A06 | Cast button hidden when unsupported | ⬜ |
| 7 | R12-A07 | Native macOS PiP evaluated | ⬜ |
| 8 | R12-A08 | In-app updates polished (RFC-015) | ⬜ |

---

## Goal

Polish the unified player UX (Cineby/Rive-style overlay with in-player server grid) and add native casting on mobile/desktop where supported.

## Deliverables

### 1. Player overlay (RFC-003)

Wire existing stubs into `shared/player/`:

| Component | Path | Action |
|-----------|------|--------|
| `PlayerOverlayPanel` | `shared/design/src/player_overlay.dart` | Mount in desktop/mobile player |
| `ServerGrid` | `shared/design/src/server_grid.dart` | Connect to `StreamResolver.switchProvider()` |
| `ForjaPosterCard` | `shared/design/src/poster_card.dart` | Use in browse rails (optional) |

Controls: Previous/Next, AutoNext, Details, Shuffle, PiP, Cast (picker), Watch Party (disabled).

### 2. Expanded providers (RFC-004)

Add to `packages/streaming/lib/src/provider_registry.dart`:

| Provider | v1.0 | v1.1 |
|----------|------|------|
| Videasy, Vidsrc, VidLink, VixSrc, Vidnest, 111477, Vidzee, VidRock | yes | yes |
| RiveEmbed, SmashyStream, VidFast | | add |
| 2Embed, AutoEmbed, MultiEmbed | | add |
| PrimeSrc, VidSrc.wtf API | | add |

Settings: enable/disable + drag order via `ProviderSettingsRepo`.

### 3. Casting (RFC-005)

Implement `CastingService` platform channels:

| Platform | AirPlay | Chromecast |
|----------|---------|------------|
| macOS | AVRoutePickerView | N/A |
| iOS | Native route | Google Cast SDK |
| Android | N/A | Google Cast SDK |
| Windows/Linux | N/A | DLNA optional (v2+) |

VOD: cast resolved URL; use `LocalServerService` proxy when Referer required.  
IPTV live: best-effort via HLS proxy transmux.


## Related RFCs

RFC-003, RFC-004 (expansion), RFC-005, RFC-015, [RFC-019](019-[draft]-god-file-decomposition.md) (god file splits), [RFC-020](020-[draft]-media-details-routing.md) (media details routing)

## Prerequisites

Complete [RFC-016](016-[partial]-lazy-tab-mounting.md)–[018](018-[draft]-startup-splash-home.md) (v1.0.1 performance) before or in parallel with overlay work. Player control extraction in RFC-019 unblocks RFC-003 wiring.
