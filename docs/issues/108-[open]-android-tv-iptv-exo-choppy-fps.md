# 108 — Android TV IPTV ExoPlayer choppy FPS on weak / Android 7 SoCs

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · Media3 ExoPlayer · SurfaceView · MediaKit  
**Reported:** 2026-07-25 (Toshiba Android 7 TV)

## Status at a glance

| | |
|--|--|
| **Progress** | **17 / 17** fix · **0 / 6** acceptance |
| **Current slice** | ATV emulator IPTV: force Exo (MediaKit HEVC ANR); physical ATV MediaKit unchanged |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I108-T01 | Exo `open`: live LoadControl + LiveConfiguration + device max video size/bitrate (API ≤25 → 720p, ATV → 1080p) | ✅ |
| 2 | I108-T02 | IPTV ATV Exo open passes `live` from URL (`/live/` / M3U vs `/movie/` `/series/`) | ✅ |
| 3 | I108-T03 | Unit test `iptvExoUrlLooksLive` | ✅ |
| 4 | I108-T04 | Drop automatic live height/bitrate caps; shorter live target offset (~8s) — caps made picture soft / unwatchable | ✅ |
| 5 | I108-T05 | IPTV honors Settings / Player menu Exo ↔ MediaKit (ATV MediaKit uses `vo=mediacodec_embed`) | ✅ |
| 6 | I108-T06 | ATV Exo: SurfaceView + Flutter hybrid composition (TextureView low-FPS / soft on leanback); phone keeps TextureView | ✅ |
| 7 | I108-T07 | ATV MediaKit IPTV: `video-sync=display-resample` + `framedrop=vo`; Exo live decoder fallback + wake mode | ✅ |
| 8 | I108-T08 | IPTV Exo: skip no-op buffering/playing setState; skip progress setState when chrome hidden | ✅ |
| 9 | I108-T09 | Settings → **IPTV live max quality** (Auto default = no cap; 1080/720/480 opt-in only) | ✅ |
| 10 | I108-T10 | ATV **emulator**: force Exo TextureView + TLHC (goldfish SurfaceView → audio-only / chrome covered); physical ATV unchanged | ✅ |
| 11 | I108-T11 | Display frame-rate matching now covers **live** (was VOD-only, issue 151 T03): a 50/25 fps channel on a fixed 60 Hz panel judders exactly like low FPS. One switch per open, so a ladder flip cannot re-trigger an HDMI re-sync | ✅ |
| 12 | I108-T12 | `forceEnableMediaCodecAsynchronousQueueing()` — Media3 only enables async queueing by default on API 31+, so Android 7 TVs queued codec work on the playback thread | ✅ |
| 13 | I108-T13 | Frame-health logging to `logcat -s ForjaExo` (decoder name, input format + fps, dropped-frame counts) — `setEnableDecoderFallback(true)` can silently swap in a software decoder, which is indistinguishable from a compositing stutter from the couch | ✅ |
| 14 | I108-T14 | ATV **emulator** MediaKit: force software decode (`hwdec=no`, no `mediacodec_embed`) — goldfish HEVC 1080p hangs MediaCodec until input ANR; physical ATV unchanged | ✅ |
| 15 | I108-T15 | ATV **emulator** IPTV: force **Exo** at boot + hide/block MediaKit in Player menu — T14 software path hits `EGL_BAD_ATTRIBUTE` (black / empty cache); format-error auto-swap must not bounce into MediaKit | ✅ |
| 16 | I108-T16 | **Revert T14–T15** — restore ATV MediaKit `vo=mediacodec_embed` + `hwdec=mediacodec` on emulator (T14 killed paint via EGL; T15 was a workaround for that self-inflicted regression). Goldfish HEVC ANR on some channels remains an emulator limit, not a ship blocker | ✅ |
| 17 | I108-T17 | ATV **emulator** IPTV: force Exo + rewrite IPTV engine pref + hide MediaKit in Player menu — restored MediaKit HW (T16) still ANRs on 1080p HEVC (`c2.goldfish.hevc.decoder`); Exo TextureView path is the working engine on this AVD | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I108-A01 | Toshiba Android 7 TV (or API 24 leanback): IPTV **live** channel plays without constant choppy FPS (Home/Search movies still smooth) | ⬜ |
| 2 | I108-A02 | Default Auto: live IPTV plays full portal quality (no forced downscale); opt-in 720p/1080p only when user sets **IPTV live max quality** | ⬜ |
| 3 | I108-A03 | Android TV IPTV **Player** menu switches Exo ↔ MediaKit and shows video (not black) on MediaKit | ⬜ |
| 4 | I108-A04 | Android TV **emulator**: IPTV Exo shows video + player chrome (not audio-only black / covered UI) | ⬜ |
| 5 | I108-A05 | Toshiba Android 7: a 50/25 fps live channel on Exo plays fluidly; `logcat -s ForjaExo` shows a hardware decoder and no sustained dropped-frame lines | ⬜ |
| 6 | I108-A06 | Android TV **emulator**: IPTV boots Exo (MediaKit not offered); HEVC channel stays alive (no SIGQUIT) | ⬜ |

---

## Summary

On **Android TV**, IPTV and Home/Search movies both use Media3 ExoPlayer by default. Home VOD was smoother; **IPTV live** felt like constant low FPS on a Toshiba Android 7 set. MediaKit (`mediacodec_embed`) looked more fluid.

**Root cause (initial):** Live Xtream/M3U feeds are often fixed high-bitrate MPEG-TS (or high HLS variants) at the live edge. The shared Exo host had **no live LoadControl**, **no LiveConfiguration**, and **no max video size/bitrate** — while movie playback uses ABR + device caps in source selection. Weak API 24 TV SoCs + TextureView compositing fall behind first on live.

**First fix (T01–T03):** when Dart opens with `live: true` (IPTV live URLs), native Exo applies larger live buffers, a live offset, and track caps (720p / ~3.5 Mbps on API ≤25; 1080p / ~5 Mbps on other ATV).

**Follow-up (T04–T05):** device caps made live look soft / low-FPS and unwatchable. Caps are removed by default (LoadControl + ~8s live offset remain). IPTV now reads **Settings → Built-in engine** and the in-player **Player** menu can hot-swap Exo ↔ MediaKit; ATV MediaKit uses `vo=mediacodec_embed` + `hwdec=mediacodec` (same as VOD).

**Surface / sync (T06–T08):** TextureView inside Flutter’s platform view has poor frame timing and often cannot paint at full leanback display resolution (UI layer upscaled — Google Media3 guidance prefers SurfaceView on ATV). ATV Exo now inflates **SurfaceView** and embeds via **hybrid composition** (`initExpensiveAndroidView`) so frames are not tiled (issue 102). Phone keeps TextureView + TLHC. MediaKit IPTV on ATV uses display-resample sync; Exo skips redundant Dart rebuilds during live.

**Emulator fallback (T10):** On goldfish/ranchu leanback emulators, SurfaceView + MediaCodec often fails `setOutputSurface` (`BAD_INDEX`) → audio continues, picture stays black, and the separate Surface can cover Flutter player chrome. Emulators force **TextureView** + phone TLHC path for Exo; physical ATVs keep SurfaceView.

**Emulator MediaKit (T14–T17):** T14 software decode dropped `mediacodec_embed` → `EGL_BAD_ATTRIBUTE` / black. T15 forced Exo; T16 restored MediaKit HW. Restored MediaKit still ANRs on 1080p HEVC (`c2.goldfish.hevc.decoder`, SIGQUIT). **T17:** ATV emulator IPTV forces **Exo**, rewrites the IPTV engine pref away from MediaKit, and hides MediaKit in the Player menu. Physical ATVs keep MediaKit HW.

**Opt-in quality (T09):** **Settings → Playback → IPTV live max quality** defaults to **Auto (full quality)**. Choosing 1080p / 720p / 480p applies an Exo track ceiling for live adaptive feeds only — never automatic.

**Limit:** single-variant TS above what the SoC can decode may still hitch — try **MediaKit** from the Player menu, or optionally set **IPTV live max quality** when the feed has adaptive variants.

**Update (issue 133 T07):** the SurfaceView path (T06) is now **parked**. Physical sets reported IPTV Exo audio-only black even on cold open, and the composition-dead surface still fires `renderedFirstFrame` so the watchdog cannot fall back. IPTV Exo now **always** uses TextureView (matching VOD). The SurfaceView machinery stays wired for a possible per-device opt-in.

**Fluid Exo on TextureView (T11–T13).** Defaulting Android TV IPTV to MediaKit was tried and **reverted** — it abandoned Exo instead of fixing it, and the unset IPTV key inherits the VOD engine again. The remaining judder was attacked on the Exo side:

- **Frame-rate matching was never reaching live.** `applyContentFrameRate()` returned early on `lastOptions.live`, so a 50 or 25 fps channel stayed on the TV's fixed 60 Hz mode — an uneven cadence that reads as "less FPS" even when every frame is delivered on time. The `frameRateApplied` one-shot already prevents a ladder flip from re-triggering an HDMI re-sync, so the live exclusion was unnecessarily blunt.
- **Async MediaCodec queueing was off.** Media3 enables it by default only on API 31+, leaving Android 7 TVs queueing codec work on the playback thread.
- **Software decode was invisible.** `setEnableDecoderFallback(true)` can silently drop to a software decoder; from the couch that looks identical to a compositing stutter. Decoder name, input format/fps, and dropped-frame counts now log under `ForjaExo`.

**Still true:** TextureView costs a per-frame copy into a Flutter texture that SurfaceView and mpv's `mediacodec_embed` both avoid. The architectural fix is rendering Exo into a Flutter external texture (`TextureRegistry`) instead of a PlatformView — the path the official `video_player` plugin uses. Not attempted here; it would drop `PlayerView` and move subtitle rendering into Flutter.

## Related

- [102](102-[open]-android-tv-exoplayer-tiled-frames.md) — SurfaceView tiling under TLHC; ATV now uses hybrid composition
- [133](133-[open]-android-tv-exo-physical-audio-only.md) — physical ATV SurfaceView audio-only (even cold open) → IPTV Exo forced to TextureView; T06 SurfaceView FPS slice parked
- [092](092-[open]-windows-iptv-stream-freeze-after-20s.md) — Windows MediaKit IPTV freeze (separate)
- [107](fixed/107-[fixed]-android-7-tmdb-lets-encrypt-trust.md) — same Toshiba device, posters only
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../features/playback/player.md)
