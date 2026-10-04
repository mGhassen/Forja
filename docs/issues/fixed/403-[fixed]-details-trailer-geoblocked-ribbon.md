# 403 — Details trailer cards: Geoblocked ribbon

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** `youtube_stream_service.dart` · details trailers section

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I403-T01 | Detect country-restriction errors on YouTube trailer resolve | ✅ |
| 2 | I403-T02 | Prefetch all details trailers; notify when geo status changes | ✅ |
| 3 | I403-T03 | Paint **Geoblocked** corner ribbon on foundation trailer cards | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I403-A01 | Details Trailers row: a country-blocked YouTube key shows a Geoblocked ribbon on that card after prefetch | ⬜ |

---

## Summary

YouTube resolve can fail with `VideoUnplayableException` when the uploader has not made the video available in the user’s country. The failure was only logged; the Trailers row still looked playable.

### Fix

- `YoutubeStreamService` records geo-blocked video ids and bumps `geoblockEpoch`
- Details trailers host listens and passes `geoblocked` into foundation paint
- Foundation trailer thumb shows a red diagonal **Geoblocked** ribbon

### Related

- [RFC-055](../../rfc/055-[open]-native-youtube-trailer-player.md) — native YouTube trailer player
