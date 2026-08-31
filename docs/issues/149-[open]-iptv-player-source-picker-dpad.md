# 149 — IPTV/Live player source picker has no D-pad, and two controls open it

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV / Live Matches player chrome · Android TV D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I149-T01 | Replace the `showModalBottomSheet` source picker with `PlayerPopupPanel` + `PlayerPopupListTile` (same chrome as Player / Stats / Quality menus) | ✅ |
| 2 | I149-T02 | Autofocus the active source on TV and let remote Back close the panel through `dismissAnyPlayerChromeOverlay` | ✅ |
| 3 | I149-T03 | Remove the duplicate top-bar `_SourceChip`; keep the bottom swap control and repair the top-bar ←/→ chain (Back ↔ Player) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I149-A01 | Android TV: Live Matches → Stremio match with several streams — the source panel takes focus, ↑/↓ moves between streams, OK switches | ⬜ |
| 2 | I149-A02 | Android TV: Back closes the source panel and returns focus to the bottom swap control, without exiting the player | ⬜ |
| 3 | I149-A03 | Only one source control is visible (bottom bar); top-bar ←/→ still walks Back ↔ Player ↔ Stats | ⬜ |

---

## Summary

Opening the stream list from a multi-source live match (Live Matches → Stremio sports, which hands off to `IptvPtPlayerScreen`) produced a bottom sheet the D-pad could not reach, and the same list was reachable from two different controls.

**Root cause:** the picker was a `showModalBottomSheet` whose rows used `iptvTap`, i.e. catalog-row focus meta for the `iptv` tab. The player's own chrome kept claiming focus back because `playerChromeOverlayBlocksFocusClaim()` / `playerChromeOverlayBlocksSeek()` only know about the player overlay registry (`PlayerPopupPanel`, `PlayerEpisodePanel`, …) — a raw modal route is invisible to them. Nothing in the sheet autofocused, so the remote kept driving the controls underneath.

**Fix:** the picker is now a `PlayerPopupPanel` like every other in-player menu. On TV the panel centers itself, `PlayerPopupListTile` autofocuses the active source, `TvOverlayScope` owns the D-pad, and Back pops the panel via `dismissAnyPlayerChromeOverlay()`. The redundant top-bar chip is gone; the bottom `swap_horiz` control is the single entry point and anchors the panel on desktop.

## Related

- `apps/forja/lib/features/iptv/screens/iptv_pt_player_ui.dart` — `_showSourcePicker`, `_buildTopBar`, bottom control bar
- `apps/forja/lib/shared/player/controls/player_popup_panel.dart` — panel + list tile contract
- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad parity with the movie player
- [110](110-[open]-android-tv-iptv-player-top-bar-dpad.md) — top-bar D-pad chain this change trims
- [player](../features/playback/player.md) — in-player menu map
