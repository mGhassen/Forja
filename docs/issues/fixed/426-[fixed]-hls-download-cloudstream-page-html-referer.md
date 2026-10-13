# 426 — HLS download fails on CloudStream `page-N.html` segments (Referer/Origin)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Downloads · HLS · PlayIMDb / CloudStream CDN  
**Related:** [054](054-[fixed]-vidsrc-cloudstream-referer-blocks-segments.md) · [365](../365-[open]-vod-offline-downloads.md) · [RFC-117](../../rfc/117-[open]-vod-offline-downloads.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** fix · **2/3** acceptance (app smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I426-T01 | `headersForHlsSegmentFetch` strips Referer/Origin on `page-N.html` leaf URIs | ✅ |
| 2 | I426-T02 | `HlsDownloadEngine` uses that helper for every media GET | ✅ |
| 3 | I426-T03 | PlayIMDb: API keeps Origin/Referer; stream rows UA-only; pack bump | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I426-A01 | Unit: leaf URI strips Referer/Origin; `.ts` keeps them | ✅ |
| 2 | I426-A02 | Unit: non-leaf path unchanged | ✅ |
| 3 | I426-A03 | App: PlayIMDb Server download of a CloudStream episode completes (manual) | ⬜ |

---

## Summary

Play works; Settings Downloads shows `Failed to fetch segment …/page-52.html: HTTP …` with `0 B / 0 B`.

### Root cause

CloudStream leaf segments are disguised as `page-N.html`. They return **403** when `Referer` or `Origin` is set (same CDN rule as [054](054-[fixed]-vidsrc-cloudstream-referer-blocks-segments.md)). PlayIMDb attached those headers to stream rows. Playback can still open; `HlsDownloadEngine` GETs every segment with the stored headers and fails hard on the first 403.

### Fix

- Host: strip Referer/Origin only for `page-\d+.html` segment fetches during HLS download.
- Pack: PlayIMDb keeps Origin/Referer on the API call; stream `headers` are UA-only.

### Verify

```bash
cd apps/forja && flutter test test/download_guards_test.dart
```
