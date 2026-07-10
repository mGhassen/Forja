# 024 — Local torrent URL returned before stream head; mpv format probe fails

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/torrent`, `apps/forja/lib/shared/player`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I24-T01 | Engine: `only_files` + wait for ~256 KiB stream head before returning URL | ✅ |
| 2 | I24-T02 | Player: `waitForMediaOpen` on primary torrent path; tolerate early format probe; longer timeout | ✅ |
| 3 | I24-T03 | Manual smoke: Stremio/Torrentio magnet → Local Torrent Engine plays (desktop) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I24-A01 | Magnet that works in Stremio plays via local engine without `Failed to recognize file format` abort | ⬜ |

---

## Summary

Stremio/Torrentio magnets resolve to `http://127.0.0.1:…/torrents/…/stream/…`. The Rust engine returned that URL at **metadata ready**, before any file bytes existed. The player opened mpv immediately on the no-sources path **without** `waitForMediaOpen`, so demux failed with `Failed to recognize file format`. The error listener ignored it (`probe handles fallback`) while `_playbackConfirmed` stayed false — playback never started; fallback killed the torrent and tried the next magnet (same race).

**Root fix:** prefetch stream head + select only the playback file in librqbit before returning the URL; confirm open on the primary torrent path and do not treat early format-probe errors as fatal for localhost torrent URLs.
