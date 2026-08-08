# 161 — Android TV Sources / torrent panel D-pad

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Sources panel · media details · player

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I161-T01 | `SourcesPanelTv` graph + `TvOverlayScope` / `ExcludeFocus` underlay on details Sources | ✅ |
| 2 | I161-T02 | Kind / provider / search / close edges; remove Cancel autofocus trap; register `TvCatalogRow`s | ✅ |
| 3 | I161-T03 | Source tiles register vertical list row (`tvItemIndex` + ensureVisible) | ✅ |
| 4 | I161-T04 | In-player Sources panel uses same graph (no nested overlay scope) | ✅ |
| 5 | I161-T05 | In-player torrent file picker list + close D-pad | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I161-A01 | Android TV details: open Sources → focus lands in panel; ←/→ kind tabs; ↓ providers/search/list; OK plays; Back closes | ⬜ |
| 2 | I161-A02 | Android TV player: magnet Sources overlay — same D-pad graph; chrome under panel not steals arrows | ⬜ |
| 3 | I161-A03 | Android TV player: torrent file picker ↑/↓ selects file; Back / close dismisses | ⬜ |

---

## Summary

On **Android TV**, opening the torrent **Sources** panel left D-pad on the page underneath (details Play / player chrome). Kind tabs had `tvRowId` without a registered `TvCatalogRow` / `onDownEdge`, so `shellTvHandleRowArrows` **swallowed ↓** before spatial focus could leave the strip.

**Root fix:** isolated `SourcesPanelTv` tab graph (kind → providers → search/filters → vertical list), contain + underlay `ExcludeFocus` on details, same graph for in-player Sources and torrent file picker.

---

## Related

- [160](160-[open]-android-tv-paired-playback-sources.md) — ATV paired Playback toggles unlock Sources
- [156](156-[open]-android-tv-hold-scroll-accel.md) — hold ↑/↓ accel through Sources list
- [torrent playback](../features/playback/torrent-playback.md) · [media details](../features/movies-tv/media-details.md)
