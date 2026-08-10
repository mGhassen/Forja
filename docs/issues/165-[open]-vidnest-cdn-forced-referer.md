# 165 — VidNest movie/TV CDNs fail: forced vidnest.fun Referer

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** VidNest host extract · `resolvePlaybackHttpHeaders` · player open

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix tasks · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I165-T01 | `resolvePlaybackHttpHeaders`: for `providerId: vidnest` skip policy force; keep API Referer; never invent CDN self-Referer | ✅ |
| 2 | I165-T02 | Unit tests + feature doc + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I165-A01 | Unit: `providerId: vidnest` → UA-only when headers empty; keeps API Referer; `vidnest:hianime` still megaplay policy | ✅ |
| 2 | I165-A02 | App: pin VidNest on a TMDB movie (e.g. The Amateur) — non-MovieBox servers open past CHECKING SOURCES (manual) | ⬜ |

---

## Summary

Issue [055](fixed/055-[fixed]-vidnest-moviebox-referer-429.md) stripped Referer for `*.hakunaymatata.com` only. Other VidNest CDNs (lamda / delta / alfa / prime / …) still got `Referer`/`Origin: https://vidnest.fun/` from RFC-044 `playbackPolicyFor('vidnest')` whenever the extractor sent UA-only headers. Browser playback uses no-referrer for those mirrors — open/probe failed while resolve listed many streams.

**Symptom fix (shipped):** for bare `providerId: vidnest` (movie/TV), do not force the embed policy Referer. Keep extractor/API headers when present. MovieBox strip unchanged. Anime `vidnest:*` still uses the policy path.

### Verify

```bash
cd apps/forja && flutter test test/player_playback_headers_test.dart
# Manual: pin VidNest → Play The Amateur (TMDB 1087891) — open a non-MovieBox server
```

## Related

- [055](fixed/055-[fixed]-vidnest-moviebox-referer-429.md) — MovieBox hakunaymatata strip
- [Stream providers](../../features/sources/stream-providers.md)
