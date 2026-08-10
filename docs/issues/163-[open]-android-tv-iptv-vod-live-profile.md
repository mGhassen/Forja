# 163 — IPTV Movies/Series on Android TV: open fail + live-edge ANR

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · Movies · Series · MediaKit / ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **26 / 26** fix · **0 / 3** acceptance |

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
| 17 | I163-T17 | Live MediaKit: defer display-refresh match until first frame (≤v1.3.170 open timing); skip on emulator | ✅ |
| 18 | I163-T18 | Emulator ATV MediaKit: `hwdec=no` / no `mediacodec_embed` (stop goldfish HEVC process death); physical ATV HW unchanged | ✅ |
| 19 | I163-T19 | Revert T17–T18 — Live MediaKit decode/open back to yesterday (`50ebdaa2` / HEAD): `mediacodec_embed` + inline display match | ✅ |
| 20 | I163-T20 | Restore IPTV player trio (`engine`/`screen`/`ui`) from `50ebdaa2` (2026-08-07 evening) — full Live player as yesterday | ✅ |
| 21 | I163-T21 | Restore Live MediaKit **conf** (`engine`+`screen`) from `v1.3.170` / ~2 days — no Aug-7 display-match / stall-recovery | ✅ |
| 22 | I163-T22 | `IptvPlayerChromeProfile.live` / `.vod` — Live hides Audio/Subs; Movies/Series keep tracks + episodes + VOD scrubber | ✅ |
| 23 | I163-T23 | Seekable live (duration > 1s): restore advancing MediaKit scrubber — T22 catalog-only `vodSeekChrome` left a static full bar + LIVE | ✅ |
| 24 | I163-T24 | **Full revert (user B):** restore IPTV player trio from `50ebdaa2`; drop `vodPlayback` / chrome profile / VOD gates / emu MediaKit experiments — Live path as before VOD-profile work (Movies/Series may hit live-edge ANR again) | ✅ |
| 25 | I163-T25 | Restore `IptvPlayerChromeProfile` + `vodPlayback` player stack (Audio/Subs/Episodes; VOD gates; seekable-live scrubber) after T24 — no emu MediaKit force-Exo | ✅ |
| 26 | I163-T26 | IPTV Movies/Series boot + persist Settings → Movies & series engine (`vod`); stop always-MediaKit / session-only menu | ✅ |

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

**Engine:** `I163-T07` briefly forced ATV VOD to Exo-only; **`I163-T08`–`T10`**: Movies/Series always MediaKit (menu can session-switch to Exo without writing Live’s IPTV engine key); VOD Exo hard-fail swaps once; **Live boot + recovery untouched**. **`I163-T26`**: Movies/Series honor + persist Settings → **Movies & series engine** (`vod`); Live IPTV stays on Settings → **IPTV engine**. VOD still skips live-edge snap / forever cold-retry.

**MediaKit cache (`I163-T11`):** Movies/Series inherited Live’s `demuxer-max-bytes=150MB` / 30s readahead → MediaCodec buffer pool + demuxer OOM/process death on open (goldfish/ATV). VOD now uses 32MiB / 10s; Live profile unchanged.

**Emulator VOD decode (`I163-T12` → `I163-T13`):** Tried software decode for emulator Movies/Series; **reverted** — ATV MediaKit init is back to `_atvMediaKit` + `mediacodec_embed` for all ATV (Live path identical to pre-T12). Goldfish HEVC/H264 MediaKit ANR remains an emulator limit (issue 108).

**Split profiles (`I163-T14` → `I163-T16`):** Mis-scoped “restore Live to 1.3.170” rewrite — **reverted**. Live MediaKit is again **post-170 HEAD** (keeps issue 155 no-UHD-retune, 148 recovery modes, display-refresh match, etc.). VOD lean cache (`I163-T11`) and live-profile gates (`I163-T01`–`T03`) stay. Do not rewind Live to 1.3.170 when fixing VOD.

**Live display match (`I163-T17` → `I163-T19`):** Tried deferring display-refresh match — **reverted**. Live open path matches end-of-2026-08-07 (`50ebdaa2`): MediaCodec embed + display match in the dimension probe when the setting is on.

**Emulator MediaKit SW (`I163-T18` → `I163-T19`):** Tried emulator `hwdec=no` — **reverted** (EGL black / no usable Live MediaKit paint). Live ATV MediaKit is again `mediacodec_embed` / `hwdec=mediacodec` on emulator and physical (yesterday Live decode). Goldfish HEVC process death remains an emulator limit (issue 108).

**Full Live player restore (`I163-T20`):** Checked out `iptv_pt_player_{engine,screen,ui}.dart` from `50ebdaa2` (2026-08-07 ~21:21 — still had Aug-7 display-match + stall recovery).

**MediaKit Live conf (`I163-T21`):** User asked for conf not chrome — restored `engine` + `screen` from **`v1.3.170`** (2026-08-06, ~2 days). That drops Aug-7 display-refresh match and stall/classic recovery modes. MediaKit pin is again: `mediacodec_embed` / `hwdec=mediacodec` / `display-resample`+`framedrop=vo` / UHD mid-open `video-sync=audio` / 150MB cache. UI file left as-is from T20.

**Chrome profile (`I163-T15` → `I163-T23`):** T15 gated buttons via `_isVodChrome`; T20 player restore dropped it. **T22:** `IptvPlayerChromeProfile.live` / `.vod` from catalog `vodPlayback` — Live hides Audio/Subs; Movies/Series show them (+ Episodes when list attached). **T23:** seekable live (mpv duration > 1s) uses the advancing scrubber again; pure live (no duration) keeps the EPG / live-edge track.

**Full revert (`I163-T24`):** User chose restore to pre–VOD-profile player (`50ebdaa2` trio). Removed `vodPlayback` gates, chrome profile file, series online-subs player args, and issue-108 emu MediaKit experiments layered on that stack. **Honest cost:** Movies/Series can again hit live-edge / fat-cache process death (the original 163 symptom). Acceptance A01–A03 unverified.

**Chrome profile restored (`I163-T25`):** User asked to put VOD chrome profile back after T24. Recreated `IptvPlayerChromeProfile` + restored player `vodPlayback` / series args from HEAD (T22/T23 semantics: catalog tracks; seekable live scrubber). No emulator MediaKit force-Exo. Acceptance A01–A03 still unverified.
