# 187 — Android TV movies MediaKit: cache never fills (stutter, no gray)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/` (MediaKit VOD — Home / Search / Anime / Asian Drama)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I187-T01 | RAM packet cache: `cache-on-disk=no`, `bufferSize` 100MiB, `cache-pause=yes` + wait/initial | ✅ |
| 2 | I187-T02 | Seekbar gray from `demuxer-cache-duration` (ahead of playhead), not only `demuxer-cache-time` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I187-A01 | ATV MediaKit Videasy (or similar HLS): seekbar gray grows past the playhead; CDN hitch shows BUFFERING then resumes — no frame stutter | ⬜ |
| 2 | I187-A02 | Phone MediaKit same (pause-to-refill, not hitch) | ⬜ |

---

## Summary

Movies MediaKit asked for `cache-secs=45` / `demuxer-max-bytes=100MiB` but **did not keep a usable ahead window** on Android TV:

1. media_kit defaults `cache-on-disk=yes` + `bufferSize=32MB`. With disk cache, `demuxer-max-bytes` caps **metadata**; prune looks like an empty cache. TV eMMC writes fight `mediacodec_embed`.
2. `cache-pause=no` / `cache-pause-initial=no` — underrun **plays through** (stutter) instead of BUFFERING + refill.
3. Seekbar used `stream.buffer` (`demuxer-cache-time`) and dropped events until confirm — gray stayed at zero even when packets existed.

mpv **can** prefetch multiple HLS segments into the demuxer cache (desktop gray). ATV was defeating that, not “HLS = one segment.”

**Root fix:** RAM cache, pause-to-refill, paint `position + demuxer-cache-duration`. IPTV live profile unchanged. Device smoke still open.

---

## Related

- [151](151-[open]-android-tv-exo-vod-stutter-no-cache.md) — Exo VOD buffer (different engine)
- [184](184-[open]-post-seek-buffering-remount.md) — post-seek stall remount
- [Player](../features/playback/player.md)
