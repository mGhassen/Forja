# 470 — Stream loading screen omits season/episode

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Player · loading overlay · series  
**Reported:** 2026-10-23 (product)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Playing a series episode shows the cinematic loading overlay with title/logo only. Season and episode are missing or briefly flash as `EP n` then get replaced by probe status copy.

## Root cause

1. `catalogPlayContextFromMeta` set `loadingSubtitle` to `EP $epNum` (no season). Meta-hub auto-play used the same pattern.
2. `DirectStreamLoadingPanel` replaced that subtitle with probe status hints, so S/E never stayed on screen.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I470-T01 | Format `Season S · Episode E` via `playbackLoadingEpisodeSubtitle` from play resolve + engine auto-play | ✅ |
| 2 | I470-T02 | Paint subtitle under the loading logo for the whole resolve; keep probe status as separate bottom copy | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I470-A01 | Green Play on a TV episode shows Season · Episode under the logo while providers probe | ⬜ |
| 2 | I470-A02 | In-player next episode / episode switch loading shows season and episode | ⬜ |

## Links

- Changelog: `docs/changelog/2.0.x-[draft].md` (Player)
