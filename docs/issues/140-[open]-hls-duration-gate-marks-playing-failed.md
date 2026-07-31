# 140 — HLS duration gate marks playing stream failed (0:00 / red Source)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/` — desktop/mobile open pipeline, Source panel

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I140-T01 | Hard duration gate only for progressive (skip HLS/DASH that already decoded a frame) | ✅ |
| 2 | I140-T02 | Soft-wait duration after `_playbackConfirmed` so seek bar leaves `0:00/0:00` | ✅ |
| 3 | I140-T03 | Manual source switch: stop mpv on open/decode fail; soft-wait duration after confirm | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I140-A01 | Desktop: play Cape Fear (or any title) via VixSrc — Source shows Playing now (not red ✕); time advances; seek works after duration lands | ⬜ |
| 2 | I140-A02 | Progressive MP4 with no demuxer duration still fails open (gate kept) | ⬜ |

---

## Summary

VixSrc (and similar embeds) extract **HLS**. Open + video decode succeed, but playlist duration often arrives after the 5s hard gate — or only after `_playbackConfirmed` (the UI duration listener drops pre-confirm events). The open path then `stop()` + `_markSourceFailed`, so Source shows a **red dot / ✕**, subtitle stays **1 stream** (not Playing now), and the seek bar stays **`0:00 / 0:00`** even when a frame is on screen.

**Root fix:** require seekable duration before confirm only for progressive containers that skip the decode check. Confirm HLS/DASH after a decoded frame; soft-wait for duration so the seek bar updates.

**Symptom (before):** red Source row + dead progress while video looked “playing”.
