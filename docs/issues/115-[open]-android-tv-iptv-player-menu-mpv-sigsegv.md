# 115 — Android TV IPTV Player menu: SIGSEGV in `mpv_set_property_string`

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV player · MediaKit / libmpv  
**Reported:** 2026-07-27 (Player menu → ExoPlayer while MediaKit)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I115-T01 | Guard `silenceMediaKitPlayer` / teardown — never `setProperty(waitForInitialization: false)` until libmpv create completed | ✅ |
| 2 | I115-T02 | IPTV MediaKit boot: mark `_playerReady` only after `_applyMpvTunables` (create finished) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I115-A01 | Android TV IPTV: open channel on MediaKit, Player menu → ExoPlayer — no SIGSEGV; playback continues on Exo | ⬜ |

---

## Summary

On **Android TV**, selecting **ExoPlayer** (or tearing down MediaKit) from the IPTV **Player** menu crashed the process:

```
Fatal signal 11 (SIGSEGV) … null pointer dereference
#00 mpv_set_property
#01 mpv_set_property_string
```

`x0` was `nullptr` — Dart called `mpv_set_property_string` with a null `mpv_handle`.

**Root causes:**

1. **`silenceMediaKitPlayer`** used `waitForInitialization: false` so exit would not hang on stuck VideoController init. That path skips waiting for libmpv `create`; if `ctx` is still `nullptr`, native code SIGSEGVs (Dart `try/catch` cannot catch it).
2. **IPTV `_bootPlayer`** set `_playerReady = true` *before* `_applyMpvTunables`, so the Player menu was usable while create could still be incomplete. Engine switch then silenced a not-yet-created handle.

**Fix:** Wait briefly for player init (or skip native silence) before any `waitForInitialization: false` property writes; only show the IPTV MediaKit surface after tunables (create) succeed.

## Related

- [081](fixed/081-[fixed]-macos-quit-mpv-demux-sigsegv.md) — macOS quit demux / wakeup SIGSEGV  
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — IPTV Exo ↔ MediaKit switch  
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — ATV MediaKit video path  
- [110](110-[open]-android-tv-iptv-player-top-bar-dpad.md) — IPTV Player button D-pad
