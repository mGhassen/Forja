# 128 — Android TV IPTV: MediaKit exit ANR after Player menu switch

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV player · MediaKit / MediaCodec  
**Reported:** 2026-07-28 (Player menu → MediaKit, then Back)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I128-A01 | Android TV IPTV: Player menu Exo → MediaKit, then Back — app stays alive (no ANR / force-finish) | ⬜ |
| 2 | I128-A02 | Android TV IPTV/Live: after MediaKit exit or Exo↔MediaKit switch, reopen / switch again — video plays (no black / stuck spinner) | ⬜ |

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

## Related

- [115](115-[open]-android-tv-iptv-player-menu-mpv-sigsegv.md) — Player menu SIGSEGV (null mpv handle)  
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — Exo ↔ MediaKit switch  
- [059](fixed/059-[fixed]-vod-player-audio-continues-after-exit.md) — VOD stop-before-exit  
- [IPTV Xtream](../features/live/iptv-xtream.md)
