# RFC-003: Player overlay + server grid

**Version:** v1.1 (wire stubs)  
**Status:** partial — player shipped; overlay stubs not wired  
**Target version:** [1.0.1](../backlog/1.0.1-[draft].md) (slipped from [1.0.0](done/1.0.0-[done].md))  
**Depends on:** RFC-011 (v1.0 player shell)  
**Area:** `apps/forja/lib/shared/player/`, `shared/design/src/player_overlay.dart`, `shared/design/src/server_grid.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 6** components · **0 / 4** acceptance (v1.1 slice) |
| **Current slice** | v1.1 — wire overlay + server grid |
| **Backlog** | [1.0.1](../backlog/1.0.1-[draft].md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R03-C01 | Player entry (`player_screen.dart`) | ✅ |
| 2 | R03-C02 | Desktop player | ✅ |
| 3 | R03-C03 | Mobile player | ✅ |
| 4 | R03-C04 | Overlay panel (`player_overlay.dart`) | ⬜ |
| 5 | R03-C05 | Server grid (`server_grid.dart`) | ⬜ |
| 6 | R03-C06 | Navigation (`openPlayer()`) | ✅ |

---

## Acceptance (v1.1)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R03-A01 | Overlay visible on tap / auto-hide timer | ⬜ |
| 2 | R03-A02 | Server grid switches provider without leaving player | ⬜ |
| 3 | R03-A03 | Watch Party button shows "Coming soon" | ⬜ |
| 4 | R03-A04 | PiP + Cast buttons platform-gated | ⬜ |

---


## Summary

Unified player chrome with quick actions and in-player provider switching (Cineby/Rive-style).


## Overlay controls

| Control | Behavior |
|---------|----------|
| Previous / Next | Episode navigation (series) |
| AutoNext | Toggle auto-play next episode |
| Details | Bottom sheet metadata |
| Shuffle | Random provider retry order |
| Server grid | Provider picker (RFC-004) |
| PiP | Toggle picture-in-picture |
| Cast | AirPlay/Cast picker (RFC-005, v1.1) |
| Watch Party | Disabled until RFC-008 |
| Quality / Subtitles | Shared IPTV + VOD |

## UI spec (server grid)

```
┌─────────────────────────────────────────────────┐
│  [◀ Previous]              [Next ▶]             │
│  [AutoNext] [Details] [Watch Party*] [Shuffle]  │
├─────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │ Videasy │ │ Vidnest │ │ VidLink │  ...      │
│  │ Click   │ │ ✓ Active│ │ Click   │           │
│  └─────────┘ └─────────┘ └─────────┘           │
└─────────────────────────────────────────────────┘
```

Grid columns: 5 desktop, 3 tablet, 2 phone. Active card: accent border + checkmark.

Tap card → `StreamResolver.switchProvider(id)` → re-extract → resume at same position.

## Integration plan (v1.1)

1. Import `PlayerOverlayPanel` + `ServerGrid` in desktop/mobile player
2. Pass active provider id from `StreamResolver`
3. On select → call resolver → update `PlayerScreen` stream URL in place

