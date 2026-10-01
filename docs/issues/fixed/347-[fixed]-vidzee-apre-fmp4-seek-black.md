# 347 — Vidzee Apre scrub black screen (fMP4 treated as plain HLS)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `playback_stream_guards` · peakstorm remount seek · Vidzee Apre

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I347-T01 | Classify `solarpanelcleaning.cc` (Vidzee Apre) as fMP4 remount-seek CDN | ✅ |
| 2 | I347-T02 | Trim variant picker: prefer `DEFAULT=YES` / non-HDR over top 4K HDR | ✅ |
| 3 | I347-T03 | Unit + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I347-A01 | Unit: Apre master URL matches `peakstormFmp4HlsAvoidHardSeek`; DEFAULT 1080p preferred over HDR | ✅ |
| 2 | I347-A02 | App: scrub on Vidzee Apre remounts with picture (not reconnect → black) | ⬜ |

---

## Summary

Vidzee **Apre** playlists are Peakstorm-class fMP4 HLS (`EXT-X-MAP` + `.html` segments on `*.solarpanelcleaning.cc`). Forja only remount/trimmed seeks for `peakstorm` / `dmcdn` hosts, so Apre used hard `player.seek` → BUFFERING / black, then a plain remount that looked “resumed” (PTS + video size) with no picture.

### Fix

- Treat Apre CDN hosts like Peakstorm for seek (remount + trimmed playlist)
- Prefer DEFAULT / non-HDR variants when trimming (Apre lists 4K HDR first)

### Related

- [184](../184-[open]-post-seek-buffering-remount.md) — post-seek remount watchdog  
- [331](331-[fixed]-vidzee-stale-servers-miss-v4.md) — Apre chip discovery  
- [peakstorm trim](../../features/playback/player.md)
