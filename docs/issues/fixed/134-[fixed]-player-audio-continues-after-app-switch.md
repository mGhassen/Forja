# 134 — Player audio continues after switching to another app

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · VOD player · ExoPlayer · IPTV · app lifecycle  
**Reported:** 2026-07-29 (physical ATV — Forja audible under Netflix)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I134-T01 | MediaKit mobile/TV: pause on `paused`/`hidden`/`detached`; resume if lifecycle-paused; skip PiP | ✅ |
| 2 | I134-T02 | Desktop MediaKit: same pause/resume (skip desktop PiP) | ✅ |
| 3 | I134-T03 | Exo VOD: Flutter lifecycle pause/resume + Media3 `handleAudioFocus` | ✅ |
| 4 | I134-T04 | IPTV: pause/resume on background; skip PiP | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I134-A01 | Physical Android TV: playing Forja → open Netflix → Forja audio stops; return to Forja resumes if it was playing | ⬜ |
| 2 | I134-A02 | Phone Android PiP: enter PiP while playing — audio/video keep going (no false lifecycle pause) | ⬜ |

---

## Summary

On **physical Android TV**, leaving Forja for another app (e.g. Netflix) left the VOD/IPTV decoder running — only watch-history save ran on lifecycle pause. Music already paused on audio interruption; video players did not.

**Root fix:** Pause MediaKit / Exo / IPTV when the app is backgrounded (`paused` / `hidden` / `detached`), remember that the pause was lifecycle-driven, and auto-resume on `resumed` only in that case. Skip pause while system/desktop **PiP** is active. Exo also enables Media3 audio-focus handling so a competing media app pauses Exo even without a Flutter lifecycle race.

## Related

- [059](059-[fixed]-vod-player-audio-continues-after-exit.md) — audio after **exiting** the player (stop-before-pop)
- [058](058-[fixed]-live-embed-audio-continues-after-exit.md) — live embed exit audio
- [Player](../features/playback/player.md)
