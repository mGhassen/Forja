# 510 — MegaPlay PNG-strip VOD: wrong prefetch + SW decode → freeze / lipsync snap

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** MediaKit · MegaPlay / AnimeKai · desktop + ATV · `crates/proxy` HLS strip  
**Reported:** 2026-10-28 (macOS DesktopPlayer log: `class=pngWrapTs` → `openPngStrip`; freeze then video jumps back; audio desync. ATV MediaKit same; Exo OK)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

AnimeKai / MegaPlay HLS: frame freezes every ~10s, video briefly jumps backward, audio stays out of sync. Scrobble start/pause spam is a side effect of play/pause from buffering — not the cause.

Log signature: `[OpenPipeline] … class=pngWrapTs` / `branch → openPngStrip` and (desktop) `enableHardwareAcceleration: false` / `mode=SW`.

## Root cause

1. **PNG-strip ahead prefetch used playlist *tail*** (`hls_tail_media_urls`). MegaPlay VOD lists the whole episode with `#EXT-X-ENDLIST`, so prefetch warmed the **end** of the file while the player starved at segment 0. Underrun → `video-sync=audio` snaps video to the audio clock (“go back quickly”) → lipsync break. Live sliding windows still want the tail.
2. **macOS defaulted Video decode to full SW** (`hwdec=no`) while soft TextureSW is required for chroma ([461](461-[open]-desktop-vod-sw-decode-keeps-hw-texture-pink-green.md)). Soft 1080p + strip latency underruns hard. Soft **texture** stays; decode should be VideoToolbox copy-back (`autoSafe` → `auto-copy`).

[187](187-[open]-android-tv-mediakit-vod-cache-empty.md) T03 (deeper `cache-pause-wait`) alone cannot fix a cushion that never fills ahead of the playhead. [498](fixed/498-[fixed]-mediakit-hls-av-desync-after-hiccup.md) A01 still open — same user-visible desync under strip starvation.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I510-T01 | Proxy: VOD ENDLIST prefetch **head**; live **tail**; remember playlist order; prefetch next-N after each strip segment; parallel fetch | ✅ |
| 2 | I510-T02 | macOS desktop: default Video decode `autoSafe` (soft TextureSW unchanged) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I510-A01 | Desktop MediaKit MegaPlay/AnimeKai ≥2 min — no clockwork freeze/jump-back; lipsync holds (occasional BUFFERING OK) | ⬜ |
| 2 | I510-A02 | ATV MediaKit same title — Exo-like continuity; log still `openPngStrip` when `pngWrapTs` | ⬜ |

## Links

- [187](187-[open]-android-tv-mediakit-vod-cache-empty.md) — MediaKit VOD cushion
- [498](fixed/498-[fixed]-mediakit-hls-av-desync-after-hiccup.md) — lipsync after hiccup
- [461](461-[open]-desktop-vod-sw-decode-keeps-hw-texture-pink-green.md) — soft TextureSW (kept)
- [084](084-[open]-megaplay-nekostream-cdn-referer.md) — MegaPlay strip / Referer
