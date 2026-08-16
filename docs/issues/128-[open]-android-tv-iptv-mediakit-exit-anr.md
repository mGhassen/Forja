# 128 — Android TV IPTV: MediaKit exit ANR after Player menu switch

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV player · MediaKit / MediaCodec  
**Reported:** 2026-07-28 (Player menu → MediaKit, then Back)

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I128-T01 | IPTV exit: silence + unmount Video/Exo before `Navigator.pop` (VOD `_stopPlaybackForExit` pattern) | ✅ |
| 2 | I128-T02 | Engine hot-swap: `endOfFrame` after `_playerReady = false` before dispose | ✅ |
| 3 | I128-T03 | Android MediaKit teardown uses `fast:` short stop/dispose timeouts | ✅ |
| 4 | I128-T04 | `fast:` only on exit (`_exitInProgress`); hot-swap / recreate keep full stop/dispose timeouts | ✅ |
| 5 | I128-T05 | `MpvExclusiveSession` tracks + awaits pending video dispose on Android (not macOS-only) | ✅ |
| 6 | I128-T06 | Hot-swap: VOD-style release — silence + tracked MediaKit dispose (do not await on switch); 250ms cool-down; `prepareForVideoPlayer` only when mounting MediaKit | ✅ |
| 7 | I128-T07 | VOD movies/series/anime/drama: Player-menu switch cool-down + capped `prepareForVideoPlayer` (1.2s) when mounting Exo; Exo boot same cap on Android | ✅ |
| 8 | I128-T08 | IPTV reload after Exo→MediaKit: live MediaKit reload = live-edge snap (no second `Player.open`); serialize opens; Exo soft reopen without MediaCodec release | ✅ |
| 9 | I128-T09 | VOD MediaKit→Exo: skip `ao=null` on Android silence; widget dispose defers fast teardown (do not await FFI mid-frame) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I128-A01 | Android TV IPTV: Player menu Exo → MediaKit, then Back — app stays alive (no ANR / force-finish) | ⬜ |
| 2 | I128-A02 | Android TV IPTV/Live: after MediaKit exit or Exo↔MediaKit switch, reopen / switch again — video plays (no black / stuck spinner) | ⬜ |
| 3 | I128-A03 | Android TV VOD: Player menu MediaKit → ExoPlayer — app stays alive (no ANR / force-finish) | ⬜ |

---

## Summary

On **Android TV** (reproduced on emulator `emu64a`), opening the IPTV **Player** menu and switching **ExoPlayer → MediaKit** succeeded, but pressing **Back** ~10s later ANR’d the process:

```
Input dispatching timed out … Waited 5001ms for KeyEvent
ANR in com.forjahq.app
Force finishing activity … MainActivity
Killing … user request after error
```

Flutter logs showed Select on `iptv-player-back` → `[NavBack]` then Signal Catcher SIGQUIT (ANR dump) and `Lost connection to device`. Native log timeline: Exo `Release` → MediaKit `VideoOutputManager.create` → later Back → ANR.

**Root cause:** IPTV exited with a raw `Navigator.pop` while the MediaKit `Video` (`vo=mediacodec_embed`) was still mounted. Route dispose then ran `teardownMediaKitPlayer` (stop + dispose, up to ~4s of native work) on the UI isolate interleaved with MediaCodec surface teardown → main thread blocked past the 5s input ANR window → system killed the app (looks like a crash).

**Root fix:** Same exit discipline as VOD — silence mpv, set `_playerReady = false` so the surface unmounts, wait `endOfFrame`, then pop. Hot-swap waits a frame before dispose. Exit-only Android teardown uses a short `fast:` timeout path.

**Regression (T04–T05):** Applying `fast:` to **every** Android dispose (including Player-menu hot-swap) aborted stop/dispose before mpv/MediaCodec finished, while `MpvExclusiveSession` only tracked pending dispose on macOS — the next MediaKit open raced a zombie and failed in IPTV / Live. `fast:` is exit-only; Android now waits on pending dispose before creating a new Player.

**Hot-swap kill on physical ATV (T06):** Player menu Exo ↔ MediaKit still awaited full `_disposePlayer()` on the switch path after one `endOfFrame`, so MediaKit→Exo sat in FFI stop/dispose past the ANR window (process death, no exit toast). Align with VOD: silence + track dispose without awaiting on the switch critical path, 250ms surface cool-down, and `prepareForVideoPlayer` only when mounting MediaKit (Exo does not need the mpv handle gone). Live Matches uses the same `IptvPtPlayerScreen` path.

**VOD same kill (T07):** Movies / series / anime / Asian Drama `PlayerScreen._switchPlayer` awaited full `prepareForVideoPlayer` (5s) after unmount, and `ExoPlayerScreen._boot` did the same — MediaKit→Exo on physical ATV ANR’d mid-switch. Cap Android Exo-side waits at 1.2s (trade-off vs issue 129 crop if MediaCodec is slower); MediaKit mounts keep the full wait.

**Reload after switch (T08, emu64a 2026-08-05):** Player menu Exo → MediaKit succeeded (`ExoPlayerImpl Release`), then Select on `iptv-player-replay` ~7s later ANR’d (`Waited 5001ms for KeyEvent`, `mpv/audiotrack` ~98% CPU). Reload called `Player.open` on a live mpv instance on the UI isolate. Fix: live MediaKit reload snaps to the live edge instead of re-`open`; opens are serialized; Exo `open` soft-reuses the player (`setMediaItem`) and `stop` no longer `release()`s (dispose still does).

**Regression (T08 follow-up):** An early T08 draft called `player.stop()` before every MediaKit open. On a virgin player that hung the UI isolate — first channel open after a persisted MediaKit preference ANR’d (~30s later on KeyEvent). Removed pre-open `stop`; ATV MediaKit keeps `cache-pause=no` (Lume-style pause-on-empty stays desktop/phone only).

**VOD Player-menu MediaKit→Exo (T09, emu64a 2026-08-16):** Select on Exo in the VOD Player menu ANR’d (`[LAN] release skip` then SIGQUIT). T07 capped `prepareForVideoPlayer` at 1.2s, but widget `dispose` still started full `teardownMediaKitPlayer` (`fast: false`, `ao=null`) on the UI isolate during `endOfFrame` — Dart timeouts never fire while FFI is stuck in MediaCodec drain (4K goldfish decoder in the log). Fix: Android silence skips `ao=null`; dispose schedules fast teardown and does not await it.

## Related

- [115](115-[open]-android-tv-iptv-player-menu-mpv-sigsegv.md) — Player menu SIGSEGV (null mpv handle)  
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — Exo ↔ MediaKit switch  
- [129](129-[open]-android-tv-exo-vod-cropped-after-mediakit.md) — VOD Exo crop after MediaKit (await vs ANR trade-off)  
- [059](fixed/059-[fixed]-vod-player-audio-continues-after-exit.md) — VOD stop-before-exit  
- [IPTV Xtream](../features/live/iptv-xtream.md)
