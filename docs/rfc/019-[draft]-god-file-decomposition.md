# RFC-019: God file decomposition

**Status:** draft  
**Depends on:** RFC-011 (v1.0) — prerequisite for RFC-003  
**Area:** `features/home/`, `features/settings/`, `shared/player/`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 5** acceptance · home/settings splits shipped |
| **Current slice** | Phase D complete — orchestrator 545 lines; RFC-026 media module move next |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.1)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R19-A01 | No file under `features/` or `shared/player/` exceeds ~1200 lines | ⬜ |
| 2 | R19-A02 | `features/player/` deleted | ⬜ |
| 3 | R19-A03 | Inline `_HoverScale` / `_MovieSection` removed from Home where shared widget fits | ✅ |
| 4 | R19-A04 | Settings domains in separate files | ✅ |
| 5 | R19-A05 | Player `controls/` folder with subtitle + quality extracted | ⬜ |

---


## Summary

Split oversized screens into focused files without behavior changes. Improves reviewability, testability, and parallel work — prerequisite for v1.1 player overlay work (RFC-003).

## Problem

Line counts from `wc -l` on repo HEAD — see [feature file map](../architecture/feature-file-map.md) for full inventory.

| File | Lines (approx.) | Risk |
|------|-----------------|------|
| [`details_screen.dart`](../../apps/forja/lib/features/home/details_screen.dart) | 545 | Orchestrator (state, lifecycle, panel coord); 8 `details_screen_*.part.dart` mixins |
| [`home_screen.dart`](../../apps/forja/lib/features/home/home_screen.dart) | 1372 | Phase B done — orchestrator; hero in `home_hero.dart`, sections in `widgets/` |
| [`settings_screen.dart`](../../apps/forja/lib/features/settings/settings_screen.dart) | 748 | Phase C done — orchestrator; playback/search/providers/debrid in `sections/` |
| [`iptv_pt_screen.dart`](../../apps/forja/lib/features/iptv/iptv/screens/iptv_pt_screen.dart) | 3563 | 6 sub-views + routing; 29 private widgets (IPTV — follow-on, not RFC-019 core) |
| [`live_matches_screen.dart`](../../apps/forja/lib/features/live_matches/live_matches_screen.dart) | 3539 | Models + channel UI + embed player in one file (follow-on) |
| [`mobile_player_screen.dart`](../../apps/forja/lib/shared/player/player/mobile_player_screen.dart) | 5912 | Overlay work blocked (R19-A05) |
| [`desktop_player_screen.dart`](../../apps/forja/lib/shared/player/player/desktop_player_screen.dart) | 5728 | Same |

## Rules

1. **One PR per split** — no mega-refactor
2. **No behavior change** — pure move/extract; same UI output
3. **Reuse shared widgets** — delete inline duplicates (`_HoverScale`, `_MovieSection`) in favor of [`hover_scale.dart`](../../apps/forja/lib/shared/widgets/hover_scale.dart), [`movie_section.dart`](../../apps/forja/lib/shared/widgets/movie_section.dart)
4. **Delete duplicate player folder** — [`features/player/`](../../apps/forja/lib/features/player/) is stale; canonical path is [`shared/player/`](../../apps/forja/lib/shared/player/)

## Target layout

### Home

```
features/home/
  home_screen.dart           # orchestrator, <800 lines
  home_hero.dart             # carousel, spotlight
  home_rails.dart            # MovieSection rails, pagination
  home_stremio_section.dart  # Stremio catalog blocks
  widgets/                   # private home-only widgets
```

### Details (until RFC-020 move)

```
features/home/details/
  details_screen.dart        # shell, tabs, app bar
  details_torrents.dart      # torrent/debrid UI + logic
  details_stremio.dart       # addon streams
  details_episodes.dart      # season/episode picker
```

After RFC-020, path becomes `features/media/details/`.

### Settings

```
features/settings/
  settings_screen.dart       # ListView router, search filter
  sections/
    iptv_settings.dart
    streaming_settings.dart
    stremio_settings.dart    # may wrap existing webstreamr_settings_screen
    accounts_settings.dart   # Trakt, Simkl, Jellyfin
    playback_settings.dart
    about_settings.dart      # updates, version (RFC-015)
```

Each section: standalone widget returning slivers or section body; settings_screen composes by domain.

### Player

```
shared/player/
  player_screen.dart
  player/
    mobile_player_screen.dart   # slimmed
    desktop_player_screen.dart
  controls/
    overlay_host.dart           # mounts RFC-003 overlay
    subtitle_sheet.dart
    quality_menu.dart
    menus.dart                  # move from player/menus.dart
```

Extract overlay host first — unblocks RFC-003 wiring.

## Migration order

1. Delete `features/player/` duplicate (verify imports)
2. Settings sections (low coupling)
3. Home rails + hero (medium)
4. Details sub-files (medium; coordinate with RFC-020)
5. Player controls extract (before RFC-003)

## Testing

After each PR:
- `flutter analyze`
- Manual smoke: affected tab + one unrelated tab
- No new golden tests required unless extracting pure widgets


## Related

- [Feature file map](../architecture/feature-file-map.md) — full `features/` inventory, tier classification, Phases A–E roadmap
- RFC-020 (media folder move), RFC-003 (player overlay), RFC-001 (feature boundaries), [RFC-025](fixed/025-[fixed]-flat-cinematic-shell.md) (optional `home_hero.dart` extract), [RFC-026](026-[draft]-media-details-player-ux.md) (1.0.1 UX rework — details + player splits required)
