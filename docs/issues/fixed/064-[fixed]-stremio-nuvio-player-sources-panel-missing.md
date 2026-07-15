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
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I64-T01 | Do not invent a synthetic `stremio_direct` stream row after playback confirm | ✅ |
| 2 | I64-T02 | Show Sources (link) for Stremio Direct / catalog modes even without a magnet | ✅ |
| 3 | I64-T03 | Hide layers server picker whenever catalog Sources is available | ✅ |
| 4 | I64-T04 | Match current HTTP Stremio/Nuvio URL in player Sources panel highlight | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I64-A01 | Play Stremio/Nuvio film without magnet → link Sources opens torrent/Stremio list; no `stremio_direct` layers picker | ⬜ |

---

## Summary

Opening a film via Stremio or Nuvio set `activeProvider: stremio_direct` without a magnet. After open, `_refreshPanelPlayingStream` invented a one-row source titled `stremio_direct`, which turned on the layers **Source** server picker. The real **Sources** right panel (torrents + Stremio) only appeared when a magnet was set — so direct HTTP Stremio/Nuvio sessions never offered the catalog panel.

**Root fix:** treat catalog modes via `isCatalogSourcesMode`, skip synthetic panel rows for those modes, and gate the Sources button on magnet **or** catalog mode.
