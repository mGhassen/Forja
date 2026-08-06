# Issue 153 — KissKh HLS: first frame then indefinite BUFFERING (4K ladder)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Asian Drama / KissKh playback (`shared/player/player/`, `kisskh`)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I153-T01 | Open KissKh HLS at a ≤1080p (or Settings max) media playlist instead of the master ABR URL | ✅ |
| 2 | I153-T02 | Keep quality-menu parse on the master URL when play already opened a capped variant | ✅ |
| 3 | I153-T03 | One-shot stall recovery: after confirm, if BUFFERING ≥18s with pos≈0, drop to lowest rung | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I153-A01 | macOS: a title that previously stuck on BUFFERING after the splash frame advances past ~2s without hanging | ⬜ |
| 2 | I153-A02 | Logs show `[Player] KissKh HLS cap ≤…p → variant` (or stall drop) when the master has rungs above the cap | ⬜ |

---

## Summary

**Symptom:** Asian Drama play resolves (`native resolve ok`) and opens (`openDirect`), TextureGL gets a first frame (often a title splash at 3840×2160), then ABR ladders 4K→1440→720→480 while the player UI stays on **BUFFERING / 0 / 1** indefinitely.

**Root:** KissKh masters commonly include 4K rungs. mpv `hls-bitrate` only influences initial track pick and is unreliable when bandwidth tags are wrong — playback starts on 4K, starves, and VOD has no IPTV-style stall recovery. Mid-play HTTP errors are also treated as ignorable, so the UI never fails over.

**Fix:** Cap KissKh opens to a concrete ≤1080p (or Settings max) media playlist; if still stuck near 0:00 buffering for 18s, drop once to the lowest listed rung.
