# RFC-003: Player overlay + server grid

**Version:** v1.1 (wire stubs)  
**Status:** Partial — player shipped; overlay stubs not wired

## Summary

Unified player chrome with quick actions and in-player provider switching (Cineby/Rive-style).

## Components

| Piece | Path | Status |
|-------|------|--------|
| Player entry | `apps/forja/lib/shared/player/player_screen.dart` | Shipped |
| Desktop player | `shared/player/player/desktop_player_screen.dart` | Shipped |
| Mobile player | `shared/player/player/mobile_player_screen.dart` | Shipped |
| Overlay panel | `shared/design/src/player_overlay.dart` | Stub |
| Server grid | `shared/design/src/server_grid.dart` | Stub |
| Navigation | `shell/app_router.dart` → `openPlayer()` | Shipped |

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

## Acceptance (v1.1)

- [ ] Overlay visible on tap / auto-hide timer
- [ ] Server grid switches provider without leaving player
- [ ] Watch Party button shows "Coming soon"
- [ ] PiP + Cast buttons platform-gated
