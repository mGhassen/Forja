# 024 — Local torrent URL returned before stream head; mpv format probe fails

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/torrent`, `apps/forja/lib/shared/player`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I24-T01 | Engine: `only_files` + wait for ~256 KiB stream head before returning URL | ✅ |
| 2 | I24-T02 | Player: `waitForMediaOpen` on primary torrent path; tolerate early format probe; longer timeout | ✅ |
| 3 | I24-T03 | Manual smoke: Stremio/Torrentio magnet → Local Torrent Engine plays (desktop) | ⬜ |
| 4 | I24-T04 | `waitForMediaOpen`: local torrent readiness requires decoded video (not buffer/moov alone) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I24-A01 | Magnet that works in Stremio plays via local engine without `Failed to recognize file format` abort | ⬜ |

---

## Summary

Stremio/Torrentio magnets resolve to `http://127.0.0.1:…/torrents/…/stream/…`. The Rust engine returned that URL at **metadata ready**, before any file bytes existed. The player opened mpv immediately on the no-sources path **without** `waitForMediaOpen`, so demux failed with `Failed to recognize file format`. The error listener ignored it (`probe handles fallback`) while `_playbackConfirmed` stayed false — playback never started; fallback killed the torrent and tried the next magnet (same race).

**Root fix:** prefetch stream head + select only the playback file in librqbit before returning the URL; confirm open on the primary torrent path and do not treat early format-probe errors as fatal for localhost torrent URLs.

### Follow-up (I24-T04)

After T01/T02, Torrents-tab magnets could still **false-confirm** open: `waitForMediaOpen` treated buffer / moov duration / playing as ready while `videoParams` stayed `0×0`. Playback looked frozen (black screen + abortive `completed` loops). Stremio/Torrentio magnets that actually decoded a frame still worked. Fix: local torrent URLs require `hasDecodedVideo` before settle (same bar as `sourceRequiresVideoDecode` on the sources path).
