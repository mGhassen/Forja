# 024 — Local torrent URL returned before stream head; mpv format probe fails

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/torrent`, `apps/forja/lib/shared/player`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I24-T01 | Engine: `only_files` + wait for ~256 KiB stream head before returning URL | ✅ |
| 2 | I24-T02 | Player: `waitForMediaOpen` on primary torrent path; tolerate early format probe; longer timeout | ✅ |
| 3 | I24-T03 | Manual smoke: Stremio/Torrentio magnet → Local Torrent Engine plays (desktop) | ⬜ |
| 4 | I24-T04 | `waitForMediaOpen`: local torrent readiness requires decoded video (not buffer/moov alone) | ✅ |
| 5 | I24-T05 | Engine: TCP listen + sandbox DHT persist; 180s head wait; accept ≥16 KiB partial head; richer timeout stats | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I24-A01 | Magnet that works in Stremio plays via local engine without `Failed to recognize file format` abort | ⬜ |
| 2 | I24-A02 | Magnet that plays in qBittorrent / PlayTorr also starts via Local Torrent Engine (desktop) | ⬜ |

---

## Summary

Stremio/Torrentio magnets resolve to `http://127.0.0.1:…/torrents/…/stream/…`. The Rust engine returned that URL at **metadata ready**, before any file bytes existed. The player opened mpv immediately on the no-sources path **without** `waitForMediaOpen`, so demux failed with `Failed to recognize file format`. The error listener ignored it (`probe handles fallback`) while `_playbackConfirmed` stayed false — playback never started; fallback killed the torrent and tried the next magnet (same race).

**Root fix:** prefetch stream head + select only the playback file in librqbit before returning the URL; confirm open on the primary torrent path and do not treat early format-probe errors as fatal for localhost torrent URLs.

### Follow-up (I24-T04)

After T01/T02, Torrents-tab magnets could still **false-confirm** open: `waitForMediaOpen` treated buffer / moov duration / playing as ready while `videoParams` stayed `0×0`. Playback looked frozen (black screen + abortive `completed` loops). Stremio/Torrentio magnets that actually decoded a frame still worked. Fix: local torrent URLs require `hasDecodedVideo` before settle (same bar as `sourceRequiresVideoDecode` on the sources path).

### Follow-up (I24-T05)

Healthy magnets that worked in qBittorrent / PlayTorr still failed in Forja with `Timed out waiting for torrent stream head`. Root causes vs desktop clients:

1. **No TCP listen** — session was outgoing-only (`listen: None`), so many swarms never delivered pieces
2. **Cold DHT every boot** — persistence disabled for sandbox; now dumped under `{temp}/torrent/dht_state.json`
3. **Hard 60s / 256 KiB abort** — raised to 180s / prefer 64 KiB, and accept ≥16 KiB partial head so mpv can keep pulling
4. **Default public trackers + DHT bootstraps** that answer on this network

**Verified (2026-07-16):** `stream_head_from_bbb_torrent_file` — Big Buck Bunny `.torrent` → stream URL + HTTP `206` / 1024 bytes in <1s.  
**Not verified here:** live magnet metadata for BBB (`stream_head_from_public_magnet` / Flutter `TORRENT_E2E`) — peers connect but often lack `ut_metadata` on that swarm; user's HOTD log had already passed metadata and failed at stream-head.

Manual smoke (`I24-T03`, `I24-A01`–`A02`) still required on a real indexer magnet.
