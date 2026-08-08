# 163 — IPTV Movies/Series on Android TV: open fail + live-edge ANR

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · Movies · Series · MediaKit / ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **16 / 16** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I163-T01 | `vodPlayback` flag from catalog kind / series episode open; `_livePlaybackProfile` gates live-only paths | ✅ |
| 2 | I163-T02 | Never `_scheduleJumpToLive` / post-open snap for VOD (fixes series `drop-buffers`+seek ANR) | ✅ |
| 3 | I163-T03 | Stable healthy-hold + buffering-done “video alive” live-only; VOD finite recovery (no forever cold-retry) | ✅ |
| 4 | I163-T04 | ATV VOD boots Exo; hard open fail → one-shot engine swap (`iptvIsHardOpenFail`) | ✅ |
| 5 | I163-T05 | Series episode open passes `vodPlayback` + onlineSubtitles | ✅ |
| 6 | I163-T06 | ATV VOD chrome: progress scrubber + Audio/Subs (+ Episodes on series); Exo online subs | ✅ |
| 7 | I163-T07 | ATV Movies/Series: omit/refuse MediaKit in Player menu + auto-swap (Exo only) | ✅ |
| 8 | I163-T08 | Restore MediaKit for ATV Movies/Series (Player menu + engine pref + auto-swap); keep `vodPlayback` live-profile gates | ✅ |
| 9 | I163-T09 | Remove Player menu `allowMediaKit` kill-switch; VOD Exo `Source error` / 403 → one-shot MediaKit swap | ✅ |
| 10 | I163-T10 | Movies/Series always MediaKit boot; VOD engine menu session-only (no Live IPTV pref write); Live boot/recovery untouched | ✅ |
| 11 | I163-T11 | Movies/Series MediaKit: lean demuxer cache (32MiB / 10s); Live keeps 150MB / 30s | ✅ |
| 12 | I163-T12 | Emulator Movies/Series MediaKit: software decode (no goldfish mediacodec); physical ATV + Live stay `mediacodec_embed` | ✅ |
| 13 | I163-T13 | Revert T12 — restore ATV MediaKit init to `_atvMediaKit` / `mediacodec_embed` for all ATV (Live untouched) | ✅ |
| 14 | I163-T14 | Split MediaKit profiles: Live = 1.3.170 tunables; Movies/Series = Home VOD-style (no live reconnect/cache) | ✅ |
| 15 | I163-T15 | Live chrome hides Audio/Subs; Movies/Series keep track buttons (`_showTrackButtons` → `_isVodChrome`) | ✅ |
| 16 | I163-T16 | Revert T14 — restore Live MediaKit to post-170 HEAD (keep 155/148); do not rewind Live to 1.3.170 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I163-A01 | ATV IPTV movie plays (or engine-swaps once) — no stuck `skip recovery … working` after Failed to open | ⬜ |
| 2 | I163-A02 | ATV IPTV series episode plays without process death / SIGQUIT after open | ⬜ |
| 3 | I163-A03 | ATV IPTV **live** still live-edge snaps when seekable; Stable skip-recovery on hiccups unchanged | ⬜ |

---

## Summary

IPTV Movies/Series reused the **live** player profile: post-open `drop-buffers` + `seek 99999` on seekable VOD (ANR on goldfish/ATV MediaKit), and Stable recovery treated buffering-done as “working” so `Failed to open` never recovered.

**Fix:** Catalog-driven `vodPlayback` (and URL fallback via `_livePlaybackProfile`). Live paths unchanged when `vodPlayback` is false. VOD chrome: scrubber + Audio/Subs (+ Episodes on series).

**Engine:** `I163-T07` briefly forced ATV VOD to Exo-only; **`I163-T08`–`T10`**: Movies/Series always MediaKit (menu can session-switch to Exo without writing Live’s IPTV engine key); VOD Exo hard-fail swaps once; **Live boot + recovery untouched**. VOD still skips live-edge snap / forever cold-retry.

**MediaKit cache (`I163-T11`):** Movies/Series inherited Live’s `demuxer-max-bytes=150MB` / 30s readahead → MediaCodec buffer pool + demuxer OOM/process death on open (goldfish/ATV). VOD now uses 32MiB / 10s; Live profile unchanged.

**Emulator VOD decode (`I163-T12` → `I163-T13`):** Tried software decode for emulator Movies/Series; **reverted** — ATV MediaKit init is back to `_atvMediaKit` + `mediacodec_embed` for all ATV (Live path identical to pre-T12). Goldfish HEVC/H264 MediaKit ANR remains an emulator limit (issue 108).

**Split profiles (`I163-T14` → `I163-T16`):** Mis-scoped “restore Live to 1.3.170” rewrite — **reverted**. Live MediaKit is again **post-170 HEAD** (keeps issue 155 no-UHD-retune, 148 recovery modes, display-refresh match, etc.). VOD lean cache (`I163-T11`) and live-profile gates (`I163-T01`–`T03`) stay. Do not rewind Live to 1.3.170 when fixing VOD.

**Chrome profile (`I163-T15`):** Live bottom chrome hides **Audio** / **Subtitles** (any engine). Movies/Series keep track buttons via `_isVodChrome` (`vodPlayback` / duration).
