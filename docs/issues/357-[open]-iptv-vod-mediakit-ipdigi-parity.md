# 357 — IPTV Movies/Series MediaKit: match ipdigi VOD (truncation stutter)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV · Movies · Series · MediaKit · macOS / desktop / ATV

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I357-T01 | VOD MediaKit cache = ipdigi: 128 MiB / 30 s / 30 s readahead, `cache-pause=yes`, ATV RAM-only, `force-seekable` | ✅ |
| 2 | I357-T02 | VOD MediaKit mid-stream: ignore socket / premature-EOF / error reopen — lavf reconnect owns truncations | ✅ |
| 3 | I357-T03 | VOD MediaKit watchdog: no empty-cache soft-reopen after first paint (same as live MediaKit grace-only) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I357-A01 | macOS IPTV movie: progressive Xtream “Stream ends prematurely” does not spam `skip recovery` / reopen; play continues with brief buffering | ⬜ |
| 2 | I357-A02 | ATV IPTV Movies/Series still open without MediaCodec OOM (128 MiB RAM + no disk cache) | ⬜ |

---

## Summary

Forja IPTV Movies/Series used a **lean** MediaKit VOD profile from [163](163-[open]-android-tv-iptv-vod-live-profile.md) (32 MiB / 10 s / `cache-pause=no`) plus live-style socket/watchdog recovery. Progressive Xtream files advertise ~GB `Content-Length` then close early; ffmpeg reconnects, but Forja treated truncations as recoverable while `feeding=true` with a near-empty cushion, then soft-reopened on `buffering 5s, cache empty` — stutter loop.

**ipdigi** uses fat demuxer (128 MiB / 30 s readahead), pause-to-refill, and **ignores mid-stream VOD errors** (open watchdog only). Root fix: match that VOD profile and mid-stream policy. Live IPTV path unchanged.

---

## Related

- [163](163-[open]-android-tv-iptv-vod-live-profile.md) — `vodPlayback` + lean demuxer (superseded for cushion size by this issue)
- [187](187-[open]-android-tv-mediakit-vod-cache-empty.md) — Home/Movies MediaKit `cache-pause=yes` (same refill idea)
- [RFC-113](../rfc/113-[open]-iptv-mediakit-direct-reconnect.md) — lavf reconnect (live)
