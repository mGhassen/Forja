# 517 — ExoPlayer seek bar missing IntroDB colored zones

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Android · ExoPlayer · seek bar · IntroDB  
**Reported:** 2026-10-29 (Exo VOD — blue/seafoam IntroDB markers absent; MediaKit OK)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I517-T01 | Fetch IntroDB timestamps on Exo open (skip offline download) | ✅ |
| 2 | I517-T02 | Pass `introDb` into `buildSeekBarZones` for TV + touch Exo scrubbers | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I517-A01 | TV episode with IntroDB data on Exo: scrubber shows intro (blue) / credits (seafoam) zones like MediaKit | ⬜ |

---

## Symptom

On ExoPlayer (phone / Android TV), the seek bar never painted IntroDB intro/recap/credits/preview zones. MediaKit did.

## Root cause

`ExoPlayerScreen` called `buildSeekBarZones` with only `duration` + next-episode flag — never fetched IntroDB and never passed `introDb`. MediaKit mobile/desktop already did via `_fetchIntroDbTimestamps` + `_introDbData`.

## Links

- [032](../032-[draft]-exoplayer-parity-gaps.md) — broader Exo parity tracker
- [423](423-[fixed]-offline-download-play-network-side-effects.md) — offline skips IntroDB
