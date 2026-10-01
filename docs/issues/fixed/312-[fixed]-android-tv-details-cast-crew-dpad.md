# 312 — Android TV details: D-pad jumps Cast / Characters / Crew

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · media details · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I312-T01 | Host `MediaDetailsCastSection` — `TvKitRow` + focusable avatars (cast / crew) | ✅ |
| 2 | I312-T02 | Pack details: register cast → crew → trailers → rails with ↑ to episodes/Play | ✅ |
| 3 | I312-T03 | Widget test: ↓/↑ walks cast → crew → trailers; no-rowId does not register | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I312-A01 | Widget: cast + crew rows register; ↓/↑ does not skip them | ✅ |
| 2 | I312-A02 | Android TV series details: ↓ from episodes lands on Cast/Characters (then Crew, Trailers, rails) | ⬜ |
| 3 | I312-A03 | Android TV: ↑ from Cast/Characters scrolls top and reaches episodes → Play (films: Play) | ⬜ |

---

## Summary

Cast / Characters / Crew painted on hub details but never registered in the media-details TV focus graph. Trailers and pack rails used `TvKitRow`; cast/crew only had focusable paint. ↓ from episodes jumped to Trailers / More Like This; ↑ skipped the circles.

**Root fix:** Host wire mirrors trailers — `MediaDetailsCastSection` wraps foundation paint in `TvKitRow` with per-avatar `shellFocusableTap` coords. Pack details assigns `sortOrder` and `tvFocusUp` (first meta row → episodes or Play).

### Related

- [103](../103-[open]-android-tv-anime-details-hero-focus.md) — anime details TV chrome (Related collision)
- Feature: [hub-details](../../features/hubs/hub-details.md) · [tmdb-details](../../features/movies-tv/tmdb-details.md)
