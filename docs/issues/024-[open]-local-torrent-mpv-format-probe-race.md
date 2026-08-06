# 024 — Local torrent URL returned before stream head; mpv format probe fails

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/torrent`, `apps/forja/lib/shared/player`

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 9** fix · **0 / 2** acceptance |

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
| 6 | I24-T06 | Engine: hash-validated torrent metadata cache fallback + corrected public magnet E2E fixture | ✅ |
| 7 | I24-T07 | Player: disable `force-seekable` / lavf seek on open so mpv does not Range the undownloaded tail while the swarm fills the middle | ✅ |
| 8 | I24-T08 | Player: 180s local-torrent open wait + re-open on transient format probe; engine prefer 256 KiB / min 64 KiB head | ✅ |
| 9 | I24-T09 | Player: keep torrent Range seek (`force-seekable=yes`); bound lavf probe instead of `seekable=0` (which permanently blocked scrub) | ✅ |

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

### Follow-up (I24-T06)

The public magnet E2E fixture used the wrong Big Buck Bunny info hash, so it could never retrieve matching metadata. The fixture now uses the canonical hash. Magnet startup also tries a short iTorrents `.torrent` metadata-cache lookup before DHT/tracker metadata discovery; the engine computes the returned metainfo hash and rejects it unless it exactly matches the requested magnet. Video bytes still come from peers.

**Verified (2026-07-16):**

- `metadata_cache_resolves_public_torrent` — info hash → validated `.torrent` metadata
- `stream_head_from_public_magnet` — corrected Big Buck Bunny magnet → localhost stream URL + HTTP `206` / 1024 bytes
- `stream_head_from_bbb_torrent_file` — Big Buck Bunny `.torrent` → stream URL + HTTP `206` / 1024 bytes
- Flutter `engine_smoke_test` with `TORRENT_E2E=1` — FFI magnet resolve → real localhost HTTP range response (the helper now bypasses `flutter_test`'s synthetic HTTP 400 client)

**Not verified here:** an actual decoded mpv frame through the Flutter desktop player.

Manual smoke (`I24-T03`, `I24-A01`–`A02`) still required on a real indexer magnet.

### Follow-up (I24-T07 / I24-T08) — 2026-08-06

Observed: healthy swarm (~5 MB/s, 500–600 MB downloaded) still ended **Failed to stream** with `Failed to recognize file format` and `0:00 / 0:00`. Root cause of that symptom: mpv `force-seekable=yes` + HTTP `Content-Length` of the **full** file made lavf issue Range requests for the tail (moov / probe) while those pieces did not exist yet. The swarm filled arbitrary middle pieces; open timed out at 45s × 2 and gave up while download continued.

**Fix:** open torrents sequentially (`force-seekable=no`, `stream-lavf-o=seekable=0`); wait up to 180s with periodic re-open on transient format errors; engine again prefers 256 KiB head (min 64 KiB).

### Follow-up (I24-T09) — 2026-08-06

T07 left `seekable=0` for the whole session. Runtime `force-seekable=yes` after open did **not** stick — scrub past the demuxer cache logged `Cannot seek in this stream`. Fix: drop `seekable=0`; open with `force-seekable=yes` + capped `demuxer-lavf-probesize` / `analyzeduration`; re-assert seekable on every torrent scrub.