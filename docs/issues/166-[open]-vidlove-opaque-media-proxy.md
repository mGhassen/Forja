# 166 — VidLove fails: opaque `/api?d=` media not accepted as stream

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `StreamExtractor` · VidLove / 111movies embed sniff

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix tasks · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I166-T01 | Accept signed `/api?d=&internal_token=` as playable + deferred-strong | ✅ |
| 2 | I166-T02 | VidLove/111movies: MovieBox/VidAPI chip labels + `acceptProxyPlaylistBodies` + 90s sniff / 120s SimpleResolve | ✅ |
| 3 | I166-T03 | Unit tests + feature doc + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I166-A01 | Unit: opaque proxy playable/strong; profile labels include moviebox/vidapi | ✅ |
| 2 | I166-A02 | App: pin VidLove on The Amateur — `VIDEO/STREAM DETECTED` on `/api?d=` and playback opens (manual) | ⬜ |

---

## Summary

Live VidLove sets `video.src` to a signed media proxy (`…/api?d=…&internal_token=…moviebox…`) with no `.m3u8`/`.mp4` suffix. Forja’s sniffer rejected that URL (`isPlayableStreamUrl`), held `deferUntilStrongStream` forever, then timed out → `no streams` while the browser played. Chip labels were still Neta/Gogo/Mafia/Fabric; live chips are MovieBox / VidAPI (legacy names kept).

**Symptom fix (shipped):** treat opaque signed `/api?d=&internal_token=` as playable + deferred-strong; refresh chip labels; allow proxy body scrape; budget headroom for chip rotate.

## Related

- [051](051-[open]-embed-multiserver-sniff-proxy-cookies.md) — original VidLove chip rotate
- [167](167-[open]-autoembed-cloudflare-turnstile.md) — AutoEmbed Turnstile (separate)
- [Stream providers](../features/sources/stream-providers.md)
