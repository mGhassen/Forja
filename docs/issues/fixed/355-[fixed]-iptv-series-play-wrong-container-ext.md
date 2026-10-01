# 355 — IPTV series play uses wrong container extension (`.mp4` vs `.mkv`)

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV · series VOD play · `MetaVideo` · `PackStreamPlayHooks`  
**Reported:** 2026-09-24  
**Related:** [353](353-[fixed]-iptv-series-details-missing-episodes.md) · [163](../163-[open]-android-tv-iptv-vod-live-profile.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I355-T01 | Keep `containerExt` on `MetaVideo` (parse/serialize + `open.containerExt` fallback) | ✅ |
| 2 | I355-T02 | Series play URL prefers episode `containerExt` over series poster default `mp4` | ✅ |
| 3 | I355-T03 | Unit tests for MetaVideo round-trip + `playContainerExt` precedence | ✅ |
| 4 | I355-T04 | Stop inventing `PortalLiveSourceKind.stremio` for IPTV VOD (`vod`/`iptv` → xtream; Stremio only when set) | ✅ |
| 5 | I355-T05 | Portal VOD open passes platform kind; VOD recovery stays buffered (not Xtream stall Auto) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I355-A01 | Play IPTV Series episode whose portal `container_extension` is `mkv` — MediaKit opens (not “Failed to open …`.mp4`”) | ⬜ |
| 2 | I355-A02 | Logs show play URL ending in the episode’s real extension (e.g. `.mkv`) | ⬜ |

---

## Summary

IPTV Series episodes opened as `…/series/user/pass/<id>.mp4` and MediaKit logged `Failed to open`. The same episode with `.mkv` returns HTTP 302 → playable Matroska on the portal CDN; `.mp4` returns HTTP 551 empty.

**Root:** Pack details already emit per-episode `containerExt` (and `open.containerExt`). Host `MetaVideo.fromJson` dropped that field. `PackStreamPlayHooks` then built the play URL from series-level `open.containerExt`, which catalog posters default to `mp4` when the series list has no extension.

**Fix:** Persist `MetaVideo.containerExt`; prefer episode extension when building `/series/…` URLs.
