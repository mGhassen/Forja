# 187 — Android TV movies MediaKit: cache never fills (stutter, no gray)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/screens/` (MediaKit VOD — Home / Search / Anime / Asian Drama)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I187-T01 | RAM packet cache: `cache-on-disk=no`, `bufferSize` 100MiB, `cache-pause=yes` + wait/initial | ✅ |
| 2 | I187-T02 | Seekbar gray from `demuxer-cache-duration` (ahead of playhead), not only `demuxer-cache-time` | ✅ |
| 3 | I187-T03 | Deepen refill cushion: `cache-pause-wait=20` (near `cache-secs`), `cache-secs=60`, readahead 40s, demuxer/`bufferSize` 128MiB — stop MegaPlay ~10s re-underrun loops | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I187-A01 | ATV MediaKit Videasy (or similar HLS): seekbar gray grows past the playhead; CDN hitch shows BUFFERING then resumes — no frame stutter | ⬜ |
| 2 | I187-A02 | Phone MediaKit same (pause-to-refill, not hitch) | ⬜ |
| 3 | I187-A03 | ATV MediaKit MegaPlay anime ≥2 min — no clockwork freeze every ~10s (occasional BUFFERING OK; Exo parity feel) | ⬜ |

---

## Summary

Movies MediaKit asked for `cache-secs=45` / `demuxer-max-bytes=100MiB` but **did not keep a usable ahead window** on Android TV:

1. media_kit defaults `cache-on-disk=yes` + `bufferSize=32MB`. With disk cache, `demuxer-max-bytes` caps **metadata**; prune looks like an empty cache. TV eMMC writes fight `mediacodec_embed`.
2. `cache-pause=no` / `cache-pause-initial=no` — underrun **plays through** (stutter) instead of BUFFERING + refill.
3. Seekbar used `stream.buffer` (`demuxer-cache-time`) and dropped events until confirm — gray stayed at zero even when packets existed.
4. **T01 left `cache-pause-wait=3`** while `cache-secs=45`. mpv resumes after ~3s of media; MegaPlay HLS segments are ~10s → clockwork freeze/continue. Exo keeps a 30–120s LoadControl cushion so the same CDN feels smooth. **T03** raises wait/readahead/bytes toward that cushion (desktop network VOD twin included).

mpv **can** prefetch multiple HLS segments into the demuxer cache (desktop gray). ATV was defeating that, not “HLS = one segment.”

**Root fix:** RAM cache, pause-to-refill with a real refill wait, paint `position + demuxer-cache-duration`. IPTV live profile unchanged. Device smoke still open.

---

## Related

- [151](151-[open]-android-tv-exo-vod-stutter-no-cache.md) — Exo VOD buffer (different engine)
- [184](184-[open]-post-seek-buffering-remount.md) — post-seek stall remount
- [498](fixed/498-[fixed]-mediakit-hls-av-desync-after-hiccup.md) — lipsync after hiccup (`initial-audio-sync`)
- [Player](../features/playback/player.md)
