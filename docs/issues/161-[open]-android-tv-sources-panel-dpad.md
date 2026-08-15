# 161 — Android TV Sources / torrent panel D-pad

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Sources panel · media details · player

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** fix · **0 / 6** acceptance |

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
| 6 | I161-T06 | Reclaim panel focus on open (retries); ExcludeFocus closed panel; skip Play-claim while Sources is open | ✅ |
| 7 | I161-T07 | Remote Back closes Sources/Filters only (HardwareKeyboard steal) — do not pop details or player | ✅ |
| 8 | I161-T08 | Player PopScope / pair `showDialog`: Back dismisses dialog/overlay only — HW twin must not `_exit` the player | ✅ |
| 9 | I161-T09 | Details: Back closing Sources restores D-pad to the Play control that opened it | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I161-A01 | Android TV details: open Sources → focus lands in panel; ←/→ kind tabs; ↓ providers/search/list; OK plays; Back closes | ⬜ |
| 2 | I161-A02 | Android TV player: magnet Sources overlay — same D-pad graph; chrome under panel not steals arrows | ⬜ |
| 3 | I161-A03 | Android TV player: torrent file picker ↑/↓ selects file; Back / close dismisses | ⬜ |
| 4 | I161-A04 | Android TV details: leave player → white Play → Sources still has D-pad in the panel | ⬜ |
| 5 | I161-A05 | Android TV: Back on Sources closes the panel (Filters first if open) — stays on details / in the player | ⬜ |
| 6 | I161-A06 | Android TV details: Back on Sources → D-pad on Play (not empty / Back chevron) | ⬜ |

---

## Summary

On **Android TV**, opening the torrent **Sources** panel left D-pad on the page underneath (details Play / player chrome). Kind tabs had `tvRowId` without a registered `TvCatalogRow` / `onDownEdge`, so `shellTvHandleRowArrows` **swallowed ↓** before spatial focus could leave the strip.

**Root fix:** isolated `SourcesPanelTv` tab graph (kind → providers → search/filters → vertical list), contain + underlay `ExcludeFocus` on details, same graph for in-player Sources and torrent file picker.

**I161-T06:** closed Sources still built focusable tiles off-screen; open claimed kind/list once (nodes not mounted yet → empty overlay). Closed panel is `ExcludeFocus`; open retries claim; Play-after-player skips while Sources is open.

**I161-T07:** `HardwareKeyboard` consumes `goBack` before `TvOverlayScope`, so details Back popped the title (and a player twin could leave playback). Sources now registers a dismisser: Filters first, then the panel.

**I161-T09:** closing Sources left D-pad on an empty overlay scope (panel nodes unmounted, details still `ExcludeFocus` for a frame). Back now restores the Play control that opened the panel (retries after ExcludeFocus lifts). Playback-start close does not steal Play under the player.

---

## Related

- [171](171-[open]-android-tv-details-focus-after-player.md) — details Play reclaim after player (Sources open skips that reclaim)
- [156](156-[open]-android-tv-hold-scroll-accel.md) — hold ↑/↓ accel through Sources list
- [torrent playback](../features/playback/torrent-playback.md) · [media details](../features/movies-tv/media-details.md)
