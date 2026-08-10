# 137 — Android TV: in-player engine choice not remembered per surface

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · player · IPTV · Live Matches · VOD · Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I137-T01 | Per-surface KV: `BuiltInPlayerContext` (vod / iptv / live) + `SettingsService` get/set; unset IPTV/Live fall back to VOD then platform default | ✅ |
| 2 | I137-T02 | IPTV / Live `IptvPtPlayerScreen` boot + Player menu read/write that surface (no stale `settingsPlaybackProvider` engine snap); Live handoff uses `engineContext: live` instead of always-force Exo | ✅ |
| 3 | I137-T03 | VOD `PlayerScreen` + Settings Built-in engine stay on `vod`; feature docs + changelog + unit test for context keys | ✅ |
| 4 | I137-T04 | Settings → **Movies & series engine** + **IPTV engine**; unset IPTV no longer inherits VOD; IPTV Movies/Series use `vod` context | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I137-A01 | Android TV IPTV: Player → ExoPlayer, exit, open another channel — still Exo; MediaKit switch same | ⬜ |
| 2 | I137-A02 | IPTV MediaKit + VOD Exo (or reverse) coexist — changing one surface does not change the other | ⬜ |
| 3 | I137-A03 | Live Matches native handoff remembers its own Player menu choice across reopen | ⬜ |

---

## Summary

In-player **Player** → Exo / MediaKit looked like it saved, but the next IPTV open often booted the wrong engine. Two layers:

1. **Symptom (IPTV reopen):** boot used `settingsPlaybackProvider`’s cached `builtInEngine`. The Player menu wrote KV via `SettingsService` but never patched that Riverpod snapshot, so reopen could ignore the write.
2. **Root (shared key):** one global `built_in_player_engine` meant VOD, IPTV, and Live stomped each other. User wants each surface to remember its own choice.

**Root fix:** `BuiltInPlayerContext` + per-key storage; each player reads/writes its context. Settings exposes **Movies & series** (`vod`, includes IPTV Movies/Series) and **IPTV** (`iptv`, live channels). Surfaces do not inherit each other. Live Matches stays in-player only.

## Related

- [RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md) — dual built-in engines
- [115](115-[open]-android-tv-iptv-player-menu-mpv-sigsegv.md) — IPTV Player menu Exo switch crash
- [Player](../features/playback/player.md) · [IPTV Xtream](../features/live/iptv-xtream.md) · [Playback settings](../features/settings/playback-settings.md)
