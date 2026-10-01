# 337 — Sources panel freezes with many providers / streams

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** media-details Sources · player Sources  
**Reported:** 2026-09-23  
**Fixed:** 2026-09-23

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **5 / 5** fix · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I337-T01 | Stop copying full torrent/Stremio/Nuvio lists into `playerSourcesSessionProvider` on every `setState`; bump only when fetch busy flags change | ✅ |
| 2 | I337-T02 | Drop self-`ref.watch(playerSourcesSessionProvider)` from panel `build` (panel owns list state) | ✅ |
| 3 | I337-T03 | Skip `TorrentMetaParser.parse` when no search/quality/lang/tech/audio/size filters are active; `matchesFiltersForName` uses already-parsed `this` | ✅ |
| 4 | I337-T04 | Cache filter facet sets (quality/lang/tech/size) per stream-list snapshot; single-pass `collectNameFacets` | ✅ |
| 5 | I337-T05 | Coalesce progressive torrent / Forja / Nuvio paints (~64 ms) so each provider completion does not force a full rebuild | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I337-A01 | Open Sources → Forja All on a popular title with many plugins: UI stays interactive while rows fill (scroll / chip tap / close) | ⬜ |
| 2 | I337-A02 | Torrents All progressive search: list updates without multi-second freezes as batches arrive | ⬜ |

---

## Summary

With many Forja / Nuvio / torrent providers returning streams, the Sources panel froze the app.

**Root cause:** every `setState` in `PlayerSourcesPanel` copied the full result lists into Riverpod and bumped a watched provider (self-rebuild), then `build` re-parsed every stream name several times for filters and facet chips — O(providers × streams × parses) on the UI thread.

**Root fix:** busy-flag-only session bumps · no self-watch · skip/parse-once filters · cached single-pass facets · coalesced progressive paints.

**Verify:** `apps/forja/lib/shared/player/controls/sources/panel/player_sources_panel.dart` (`setState` override, `_scheduleCoalescedPaint`) · `torrent_meta_parser.dart` (`hasActiveNameFilters`, `collectNameFacets`).

**Related:** [177](177-[open]-sources-selected-provider-lazy-fetch.md) (fetch less) · [238](fixed/238-[fixed]-live-sports-riverpod-build-stutter.md) (Riverpod rebuild stutter pattern)
