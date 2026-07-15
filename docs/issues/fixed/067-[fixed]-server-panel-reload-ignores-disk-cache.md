# 067 — Server panel reload no-op when stream started from cache

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** `shared/playback/player_source_resolve.dart`, player Source panel reload

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I67-T01 | `resolvePinnedForMovie(bypassDiskCache:)` skips disk hit and drops matching entry | ✅ |
| 2 | I67-T02 | `_loadProvider(forceRefresh:)` clears session cache, bypasses disk, refreshes `_currentSources` for active server | ✅ |
| 3 | I67-T03 | Per-server reload passes `forceRefresh: true` through `onLoadProvider` | ✅ |
| 4 | I67-T04 | Header reload falls back to force-refresh active server when `onReloadStreams` is null | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I67-A01 | After Play from webstreaming cache, Source panel server/header reload re-extracts (not instant same URLs) and re-probes streams | ⬜ |

---

## Summary

Server / header **reload** cleared only the in-memory session map, then `_loadProvider` → `resolvePinnedForMovie` immediately re-read `WebstreamingStreamCache` for the same provider and returned the same URLs. The active server row also prefers live `_currentSources` over session cache, so a silent disk hit left the panel unchanged.

**Symptom:** Reload icon does nothing (or flashes with no extract) when playback started from cache / after confirm wrote disk cache.

**Root:** Disk short-circuit + live `_currentSources` not updated on reload — not a dead button.
