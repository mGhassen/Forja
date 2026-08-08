# 163 — IPTV Movies/Series on Android TV: open fail + live-edge ANR

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV · Movies · Series · MediaKit / ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** fix · **0 / 3** acceptance |

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

**Engine:** `I163-T07` briefly forced ATV VOD to Exo-only; **`I163-T08`/`T09` restore MediaKit** (menu always lists it; no hide API; VOD Exo hard-fail / 403 swaps to MediaKit once). VOD still skips live-edge snap / forever cold-retry.
