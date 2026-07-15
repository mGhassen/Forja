# 064 — Stremio/Nuvio player shows fake server picker instead of Sources

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** `shared/player/` · `playback_stream_guards.dart`  
**Reported:** 2026-07-15  
**Fixed:** 2026-07-15

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **0 / 2** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I64-T01 | Do not invent a synthetic `stremio_direct` stream row after playback confirm | ✅ |
| 2 | I64-T02 | Show Sources (link) for Stremio Direct / catalog modes even without a magnet | ✅ |
| 3 | I64-T03 | Hide layers server picker whenever catalog Sources is available | ✅ |
| 4 | I64-T04 | Match current HTTP Stremio/Nuvio URL in player Sources panel highlight | ✅ |
| 5 | I64-T05 | Player Sources panel — Nuvio kind chip + scraper toggles (parity with details) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I64-A01 | Play Stremio/Nuvio film without magnet → link Sources opens torrent/Stremio list; no `stremio_direct` layers picker | ⬜ |
| 2 | I64-A02 | Player Sources shows **Nuvio** chip when Direct torrent + scrapers enabled; picking a row plays in-player | ⬜ |

---

## Summary

Opening a film via Stremio or Nuvio set `activeProvider: stremio_direct` without a magnet. After open, `_refreshPanelPlayingStream` invented a one-row source titled `stremio_direct`, which turned on the layers **Source** server picker. The real **Sources** right panel (torrents + Stremio) only appeared when a magnet was set — so direct HTTP Stremio/Nuvio sessions never offered the catalog panel. The player panel also omitted the **Nuvio** kind chip that media-details Sources already had.

**Root fix:** treat catalog modes via `isCatalogSourcesMode`, skip synthetic panel rows for those modes, gate the Sources button on magnet **or** catalog mode, and load Nuvio scrapers in `PlayerSourcesPanel` the same way as details (Direct torrent gated).
