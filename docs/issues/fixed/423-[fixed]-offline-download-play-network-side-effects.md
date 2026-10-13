# 423 — Offline download play still hits network APIs

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0/1** acceptance (device QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I423-T01 | Skip online subtitle scrape (Wyzie/Levrx/addons) when playing a completed local download | ✅ |
| 2 | I423-T02 | Skip Simkl scrobble start/pause/stop for offline download play (desktop / mobile / Exo) | ✅ |
| 3 | I423-T03 | Skip TMDB next-episode (and cross-season previous) lookups when playing offline | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I423-A01 | Play a finished download with airplane mode on: video plays; no Wyzie/Levrx/Simkl/TMDB next-ep errors in logs; in-stream + saved subs still listed | ⬜ |

---

## Problem

Playing a completed download while offline still fired Wyzie, Levrx, Stremio subtitle addons, Simkl scrobble, and TMDB next-episode lookups. Playback worked (`OpenPipeline` offline → `openDirect`), but logs filled with `error sending request for url`.

## Root cause

Player lifecycle always called `_fetchSubtitles()` → `SubtitleApi` and Simkl/TMDB helpers with no `isOfflineDownloadPlayUrl` gate.

## Fix

`_playingOfflineDownload` on desktop / mobile / Exo. When true: seed provider/saved external subs only (no scrape); skip Simkl scrobble; skip TMDB next-ep and cross-season previous; skip IntroDB. Hub / flat-list next-ep paths unchanged.
