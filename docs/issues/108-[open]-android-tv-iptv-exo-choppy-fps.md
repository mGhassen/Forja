# 108 — Android TV IPTV ExoPlayer choppy FPS on weak / Android 7 SoCs

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · Media3 ExoPlayer · SurfaceView · MediaKit  
**Reported:** 2026-07-25 (Toshiba Android 7 TV)

## Status at a glance

| | |
|--|--|
| **Progress** | **30 / 30** fix · **0 / 5** acceptance |
| **Current slice** | T30 player restored to `50ebdaa2` — emu MediaKit experiments T26–T29 wiped with VOD-profile revert |

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
| 18 | I108-T18 | **Revert T17 UX** — restore MediaKit in Player menu / engine switch / boot choice (user needs both engines; do not hide MediaKit) | ✅ |
| 19 | I108-T19 | ATV **emulator** Live MediaKit: lean demuxer (32MiB / 10s, same as VOD) — cut 150MB + goldfish MediaCodec buffer-pool ANR mid-play; physical ATV Live keeps 150MB / 30s; no `hwdec=no` / no Exo force | ✅ |
| 20 | I108-T20 | **Revert T19** — Live MediaKit demuxer identical on emulator and physical (150MB / 30s); user wants same profile | ✅ |
| 21 | I108-T21 | Re-apply T19 — ATV **emulator** Live MediaKit lean demuxer 32MiB / 10s; physical ATV Live 150MB / 30s (second-open goldfish OOM) | ✅ |
| 22 | I108-T22 | ATV **emulator** MediaKit: software decode (no `mediacodec_embed` / no goldfish HW); skip display-match; physical ATV HW unchanged — re-try after T14 black; process-death was worse | ✅ |
| 23 | I108-T23 | **Revert T21–T22** — emu Live MediaKit back to physical parity (`mediacodec_embed` / `hwdec=mediacodec` / 150MB); no lean-emu cache; no forced software; display-match follows setting again | ✅ |
| 24 | I108-T24 | ATV **emulator** IPTV: session-boot **Exo** (TextureView) so streams show picture; no pref rewrite; MediaKit stays in Player menu; block Exo→MediaKit format auto-swap on emu | ✅ |
| 25 | I108-T25 | **Revert T24** — user MediaKit-only; remove emulator Exo boot + Exo→MediaKit auto-swap block | ✅ |
| 26 | I108-T26 | ATV **emulator** IPTV MediaKit: `vo=gpu` + `hwdec=mediacodec-copy` (HW→GLES); physical stays `mediacodec_embed` + `mediacodec`; no Exo | ✅ |
| 27 | I108-T27 | ATV **emulator** IPTV MediaKit: back to `mediacodec_embed` + `mediacodec`; cap Surface / `android-surface-size` to **854×480** before codec + re-clamp on video-params (T26 was black+audio); physical unchanged | ✅ |
| 28 | I108-T28 | **3b+4:** remove T27 Surface clamp thrash; emulator MediaKit **never dispose/recreate** Player (soft `open` only — reuse Surface); physical unchanged | ✅ |
| 29 | I108-T29 | ATV **emulator** IPTV MediaKit **staged surface**: boot Player with `vo=null`/`vid=no`/`hwdec=no`, wait demux cache, then attach `mediacodec_embed` once; keep T28 reuse; physical unchanged | ✅ |
| 30 | I108-T30 | **With issue 163 T24:** IPTV player trio restored from `50ebdaa2` — removes T26–T29 emu MediaKit hacks; plain `mediacodec_embed` again | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I108-A01 | Toshiba Android 7 TV (or API 24 leanback): IPTV **live** channel plays without constant choppy FPS (Home/Search movies still smooth) | ⬜ |
| 2 | I108-A02 | Default Auto: live IPTV plays full portal quality (no forced downscale); opt-in 720p/1080p only when user sets **IPTV live max quality** | ⬜ |
| 3 | I108-A03 | Android TV IPTV **Player** menu switches Exo ↔ MediaKit and shows video (not black) on MediaKit | ⬜ |
| 4 | I108-A04 | Android TV **emulator**: IPTV Exo shows video + player chrome (not audio-only black / covered UI) | ⬜ |
| 5 | I108-A05 | Toshiba Android 7: a 50/25 fps live channel on Exo plays fluidly; `logcat -s ForjaExo` shows a hardware decoder and no sustained dropped-frame lines | ⬜ |

---

## Summary

On **Android TV**, IPTV and Home/Search movies both use Media3 ExoPlayer by default. Home VOD was smoother; **IPTV live** felt like constant low FPS on a Toshiba Android 7 set. MediaKit (`mediacodec_embed`) looked more fluid.

**Root cause (initial):** Live Xtream/M3U feeds are often fixed high-bitrate MPEG-TS (or high HLS variants) at the live edge. The shared Exo host had **no live LoadControl**, **no LiveConfiguration**, and **no max video size/bitrate** — while movie playback uses ABR + device caps in source selection. Weak API 24 TV SoCs + TextureView compositing fall behind first on live.

**First fix (T01–T03):** when Dart opens with `live: true` (IPTV live URLs), native Exo applies larger live buffers, a live offset, and track caps (720p / ~3.5 Mbps on API ≤25; 1080p / ~5 Mbps on other ATV).

**Follow-up (T04–T05):** device caps made live look soft / low-FPS and unwatchable. Caps are removed by default (LoadControl + ~8s live offset remain). IPTV now reads **Settings → Built-in engine** and the in-player **Player** menu can hot-swap Exo ↔ MediaKit; ATV MediaKit uses `vo=mediacodec_embed` + `hwdec=mediacodec` (same as VOD).

**Surface / sync (T06–T08):** TextureView inside Flutter’s platform view has poor frame timing and often cannot paint at full leanback display resolution (UI layer upscaled — Google Media3 guidance prefers SurfaceView on ATV). ATV Exo now inflates **SurfaceView** and embeds via **hybrid composition** (`initExpensiveAndroidView`) so frames are not tiled (issue 102). Phone keeps TextureView + TLHC. MediaKit IPTV on ATV uses display-resample sync; Exo skips redundant Dart rebuilds during live.

**Emulator fallback (T10):** On goldfish/ranchu leanback emulators, SurfaceView + MediaCodec often fails `setOutputSurface` (`BAD_INDEX`) → audio continues, picture stays black, and the separate Surface can cover Flutter player chrome. Emulators force **TextureView** + phone TLHC path for Exo; physical ATVs keep SurfaceView.

**Emulator MediaKit (T14–T30):** T14–T29 experiments (software / Exo force / lean cache / gpu-copy / surface cap / reuse / staged attach) — **T30** wiped with IPTV player restore to `50ebdaa2` (issue 163 T24). Current MediaKit = plain `mediacodec_embed` + `hwdec=mediacodec` like that evening build. Goldfish crash risk remains an emulator limit.

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
