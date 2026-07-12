# 035 — Nuvio torrent scrapers (Torrentio) leak magnets into Direct Streaming

**Priority:** P1  
**Severity:** High  
**Status:** fixed (2026-07-12)  
**Area:** `apps/forja/lib/shared/playback/stream_provider_resolver.dart`, `apps/forja/lib/shared/playback/history_playback_resume.dart`, `apps/forja/lib/features/home/details_screen.dart`  
**Reported:** 2026-07-12

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I35-T01 | Reject magnet/torrent URLs in `StreamProviderResolver` `nuvio:` branch | ✅ |
| 2 | I35-T02 | Guard cached + watch-history stream resume against replaying a torrent URL | ✅ |
| 3 | I35-T03 | Guard details-screen `_tryResumeWebStreamFromWatchHistory` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | I35-A01 | `isTorrentStreamUrl` unit test (magnet / urn:btih / .torrent vs direct) | ✅ |

---

## Summary

Nuvio scrapers are surfaced in **Direct Streaming** (the green **Play** race) as providers `nuvio:<scraperId>`. The bundled *All-in-One-Nuvio* manifest includes **Torrentio** (`nuvio:torrentio`), whose script calls the Torrentio Stremio API and returns **magnet links** as the stream `url`.

The Direct Streaming resolver treated every `nuvio:*` result as a direct HTTP stream, so it handed a `magnet:` URL to the direct player (no `magnetLink`, no torrent engine) — a torrent leaking into "direct download".

## Root cause (before fix)

`StreamProviderResolver.resolve` (`nuvio:` branch) built `StreamSource`s from **every** result of `NuvioService.runOneScraper`, including magnet URLs, and returned them as the direct-play `streamUrl`. Nothing checked the URL scheme. Stale magnets could also be replayed by the webstream resume paths (cache + watch history).

## Fix (shipped — 2026-07-12)

### Root

- `stream_provider_resolver.dart`: added top-level `isTorrentStreamUrl(url)` (matches `magnet:`, `urn:btih:`, `.torrent`). The `nuvio:` branch now filters torrent URLs out of the scraper results; if nothing direct remains the provider resolves to `null` (fails over in the race). This catches **Torrentio and any future magnet-returning scraper**, not a hardcoded id.

### Defense-in-depth (resume paths)

- `history_playback_resume.dart`: `_resumeWebStreamProvider` skips the cached-source and saved-`streamUrl` shortcuts when the URL is a torrent, falling through to a fresh (now torrent-free) resolve.
- `details_screen.dart`: `_tryResumeWebStreamFromWatchHistory` bails when the saved URL is a torrent.

### Not changed (by design)

- The **Sources** panel Nuvio path (`_runSingleNuvioScraper` → `_nuvioStreams`) and batch `getStreams`/`streamAll` are untouched — magnets there are legitimate torrent results routed through the torrent engine.

### Tests

- `apps/forja/test/torrent_stream_guard_test.dart`: `isTorrentStreamUrl` matches magnet / `urn:btih:` / `.torrent`, rejects direct HTTP(S)/HLS.

**Verify:**

```bash
cd apps/forja && flutter test test/torrent_stream_guard_test.dart
```

## Related

- [024](../024-[open]-local-torrent-mpv-format-probe-race.md) — magnets that *should* go to the torrent engine
- Feature doc: [Nuvio scrapers](../../features/scrapers/nuvio.md)

## If this file is deleted

The guard is `isTorrentStreamUrl` in `stream_provider_resolver.dart`; the `nuvio:` branch filters on it. Resume guards live in `history_playback_resume.dart` (`_resumeWebStreamProvider`) and `details_screen.dart` (`_tryResumeWebStreamFromWatchHistory`). Direct Streaming must never resolve a `magnet:` URL.
