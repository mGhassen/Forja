# RFC-117: VOD offline Downloads

**Status:** open  
**Depends on:** RFC-109 (pack-product host)  
**Area:** `apps/forja/lib/shared/downloads/`, Settings → Downloads, details / Sources / player enqueue

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 7** components · **10 / 10** acceptance |
| **Current slice** | Phase 1 shipped — Phase 2/3 deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R117-C01 | Host `DownloadTask` + `DownloadService` (HTTP Range + HLS) + persistence + wakelock | ✅ |
| 2 | R117-C02 | Dual enqueue: details/episode auto-resolve, Sources download mode, in-player current stream | ✅ |
| 3 | R117-C03 | Settings → Downloads (Active / Completed, progress, storage, delete, play offline) | ✅ |
| 4 | R117-C04 | Offline play via local path in existing player (Exo + MediaKit kept) | ✅ |
| 5 | R117-C05 | Phase 2 — debrid HTTPS + torrent Keep-offline into Downloads | ⏭️ |
| 6 | R117-C06 | Phase 3 — Android OS background (Media3 / WorkManager) + Wi‑Fi-only | ⏭️ |
| 7 | R117-C07 | Sources hover Download + reject DASH/tiny junk Completed | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R117-A01 | Details Download resolves without opening the player; enqueues HTTP/HLS with playback headers | ✅ |
| 2 | R117-A02 | Sources row can Download instead of Play | ✅ |
| 3 | R117-A03 | Player Download uses current resolved URL | ✅ |
| 4 | R117-A04 | Settings → Downloads shows Active progress and Completed library + storage used/free | ✅ |
| 5 | R117-A05 | Completed item plays offline from local file | ✅ |
| 6 | R117-A06 | Pause / resume / cancel / delete work; cold start marks interrupted as paused | ✅ |
| 7 | R117-A07 | Providers stay extract-only — no pack download verb | ✅ |
| 8 | R117-A08 | Magnets rejected in v1 auto-enqueue (Phase 2) | ✅ |
| 9 | R117-A09 | Details Download opens Sources; hover row Download enqueues (tap still plays) | ✅ |
| 10 | R117-A10 | DASH / playlist / tiny junk responses fail (not Completed) | ✅ |

---

## Summary

Host-owned offline Downloads: save a resolved play URL to disk (PlayTorrio-shaped Dart HTTP Range + HLS). Dual entry (outside player + in-player). Settings → Downloads is the management page. Packs only supply streams via `extract`.

## Out of scope (v1)

Live Sports · DRM · embed WebView · new shell nav tab · torrent/magnet offline · true OS background
