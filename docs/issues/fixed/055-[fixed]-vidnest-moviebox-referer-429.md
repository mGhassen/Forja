# 055 — VidNest: MovieBox CDN Referer causes HTTP 429

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** VidNest host extract · `resolvePlaybackHttpHeaders` · player open

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** fix · **2/3** acceptance (app smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I55-T01 | `resolvePlaybackHttpHeaders`: strip + never derive Referer/Origin for `*.hakunaymatata.com` | ✅ |
| 2 | I55-T02 | Host `VidnestExtractor`: `new.vidnest.fun` API + custom-alphabet decrypt (Gama first) | ✅ |
| 3 | I55-T03 | Wire `HostProviderAdapter` + WebView sniff fallback (`forceDirect`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I55-A01 | Curl: MovieBox MP4 200 without Referer; 429 with `Referer: https://vidnest.fun/` or CDN self-Referer | ✅ |
| 2 | I55-A02 | Unit: header helper strips hakunaymatata; cipher round-trip | ✅ |
| 3 | I55-A03 | App: pin VidNest on a TMDB movie (e.g. 550) — opens past CHECKING SOURCES (manual) | ⬜ |

---

## Summary

[VidNest](https://vidnest.fun/) works in a normal browser, but Forja failed after resolve: the Gama/MovieBox stream (`bcdn.hakunaymatata.com/…mp4`) returns **HTTP 429** whenever `Referer` is set (including the self-origin Referer Forja auto-derives). The embed player fetches with no-referrer.

### Root cause

1. Host path only WebView-sniffed `vidnest.fun` embeds and attached embed/CDN Referer on open.
2. `resolvePlaybackHttpHeaders` derived `Referer` from the stream host when missing — poisoning MovieBox opens even without extractor headers.

### Fix (shipped)

- Strip Referer/Origin for `*.hakunaymatata.com` in `resolvePlaybackHttpHeaders` (same idea as Vidsrc CloudStream / issue 054).
- Direct HTTP extract via `new.vidnest.fun` (decrypt + Gama-first server order); WebView sniff remains as fallback.
- Playback headers for MovieBox URLs are User-Agent only.

### Verify

```bash
cd apps/forja && flutter test test/player_playback_headers_test.dart test/vidnest_extractor_test.dart
# Manual: pin VidNest → Play Fight Club (TMDB 550)
```

## Related

- [054](054-[fixed]-vidsrc-cloudstream-referer-blocks-segments.md) — same header-strip pattern for CloudStream
- [Stream providers](../../features/sources/stream-providers.md)
- [VidNest docs](https://vidnest.fun/)
