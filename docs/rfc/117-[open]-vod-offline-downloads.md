# RFC-117: VOD offline Downloads

**Status:** open  
**Depends on:** RFC-109 (pack-product host)  
**Area:** `apps/forja/lib/shared/downloads/`, Settings → Downloads, Sources enqueue

## Status at a glance

| | |
|--|--|
| **Progress** | **17 / 19** components · **23 / 23** acceptance |
| **Current slice** | Phase 1 + Downloads hub shipped — Phase 2/3 deferred |

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
| 8 | R117-C08 | Sources card inline size probe + Yes/No confirm (portal-style) | ✅ |
| 9 | R117-C09 | Android TV: no Downloads UI and no download queue at boot | ✅ |
| 10 | R117-C10 | Sources lists saved / in-progress downloads before provider search | ✅ |
| 11 | R117-C11 | Details hero has no Download button; enqueue stays on Sources and the player | ✅ |
| 12 | R117-C12 | Enqueue writes a per-title page snapshot (details JSON, poster, backdrop); drama stays its own type | ✅ |
| 13 | R117-C13 | `ctx.host.downloads.titles()` lists one card per finished title | ✅ |
| 14 | R117-C14 | Downloads hub pack paints Film / Series / Anime / Asian Drama; `open.surface: offline` | ✅ |
| 15 | R117-C15 | Offline details skips the pack fetch and lists only episodes that have a finished file | ✅ |
| 16 | R117-C16 | Sources **Downloaded** tab + green Play on that page starts the first finished file | ✅ |
| 17 | R117-C17 | Saved-library card opens that page directly; its file button lists only the saved file cards | ✅ |
| 18 | R117-C18 | Saved-library card docks a side panel: saved info, finished episodes, Play, file cards only | ✅ |
| 19 | R117-C19 | Player chrome has no Download button; enqueue stays on Sources | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R117-A01 | Details Download resolves without opening the player; enqueues HTTP/HLS with playback headers | ✅ |
| 2 | R117-A02 | Sources row can Download instead of Play | ✅ |
| 3 | R117-A03 | Player Download re-extracts the pinned Forja provider (fresh URL/headers) before enqueue | ✅ |
| 4 | R117-A04 | Settings → Downloads shows Active progress and Completed library + storage used/free | ✅ |
| 5 | R117-A05 | Completed item plays offline from local file | ✅ |
| 6 | R117-A06 | Pause / resume / cancel / delete work; cold start marks interrupted as paused | ✅ |
| 7 | R117-A07 | Providers stay extract-only — no pack download verb | ✅ |
| 8 | R117-A08 | Magnets rejected in v1 auto-enqueue (Phase 2) | ✅ |
| 9 | R117-A09 | Details Download opens Sources; hover row Download enqueues (tap still plays) | ✅ |
| 10 | R117-A10 | DASH / playlist / tiny junk responses fail (not Completed) | ✅ |
| 11 | R117-A11 | Sources Download card shows size (exact or ~estimate) + free space; Yes enqueues | ✅ |
| 12 | R117-A12 | Expired Referer / HTTP 403 fails clearly — no reconnect loop on auth errors | ✅ |
| 13 | R117-A13 | Android TV: no Settings Downloads, details download, Sources download, or player download | ✅ |
| 14 | R117-A14 | Sources shows saved / in-progress downloads before provider search returns | ✅ |
| 15 | R117-A15 | Details hero has no Download button | ✅ |
| 16 | R117-A16 | Saving a title writes the details page plus poster and backdrop next to the files | ✅ |
| 17 | R117-A17 | Downloads hub shows one card per finished film, series, anime, or drama | ✅ |
| 18 | R117-A18 | Opening that card paints the saved page offline; episode list is only finished files | ✅ |
| 19 | R117-A19 | Sources on that page opens on Downloaded and lists the saved files | ✅ |
| 20 | R117-A20 | Green Play on that page starts the first finished file (film file, or lowest season and episode) | ✅ |
| 21 | R117-A21 | That card does not ask for a hub. The file button lists only the saved file cards | ✅ |
| 22 | R117-A22 | The card docks a side panel with the saved info and finished episodes. Play starts the first file. The white button lists file cards only | ✅ |
| 23 | R117-A23 | Player chrome has no Download button | ✅ |

---

## Summary

Host-owned offline Downloads: save a resolved play URL to disk (PlayTorrio-shaped Dart HTTP Range + HLS). Start a download from Sources. The details hero and the player have no Download button. Settings → Downloads is the management page. Packs only supply streams via `extract`.

## Out of scope (v1)

Live Sports · DRM · embed WebView · torrent/magnet offline · true OS background · Android TV

## Downloads hub

Settings → Downloads stays the queue. Finished titles also appear on the Downloads hub (pack layout over `ctx.host.downloads.titles()`). A card docks a side panel with the saved info and finished episodes. Play starts the first saved file. The white button lists those files. Android TV does not show that tab (`nav.hostRequires: offlineDownloads`). Titles saved before this snapshot still list from the task; the page stays thin until that title is downloaded again while its details page is open.
