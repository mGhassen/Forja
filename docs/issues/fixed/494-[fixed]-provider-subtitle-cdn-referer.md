# 494 — Provider sideload subtitles 403 without embed Referer

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** player · subtitles · EngineJS packs  
**Reported:** 2026-10-26 (macOS DesktopPlayer — AnimeKai MegaPlay “Subtitle failed”)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Provider rows (AnimeKai / MegaPlay-family) list sideload subtitles in the menu, but picking them toasts **Subtitle failed**. Video plays; CDN VTT fetch fails.

## Root cause

`catalogStreamExternalSubtitles` dropped `referer`/`origin`. Packs stamped tracks without embed headers. Download fell back to the subtitle CDN’s own origin → **403**. Desktop/Mobile logged no HTTP status.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I494-T01 | Host: pass/inherit stream `Referer`/`Origin` on external subtitle rows; shared download headers helper + status log | ✅ |
| 2 | I494-T02 | Packs: MegaPlay-family mappers stamp embed referer/origin (animekai / hianime / anikoto); bump providers pack | ✅ |
| 3 | I494-T03 | Unit: inherit stream headers + download header preference order | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I494-A01 | Manual: AnimeKai English sideload applies (no Subtitle failed toast) | ⬜ |

## Links

- Related: [084](../084-[open]-megaplay-nekostream-cdn-referer.md) (video CDN Referer)
