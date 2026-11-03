# 530 — ExoPlayer missing Skip Intro / Recap chip

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android · ExoPlayer · IntroDB · Skip chip  
**Reported:** 2026-11-03 (Exo VOD — blue intro zone on seek bar, no Skip Intro / Recap button; MediaKit OK)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I530-T01 | Track active IntroDB segment from Exo progress (recap → intro → credits → preview) | ✅ |
| 2 | I530-T02 | Mount `PlayerFloatingChip` + seek-to-end + Auto skip intro (Settings) on Exo | ✅ |
| 3 | I530-T03 | TV D-pad: Skip ↔ Next Episode ↔ seek bar focus (MediaKit mobile parity) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I530-A01 | TV/phone episode with IntroDB data on Exo: Skip Intro / Skip Recap appears while playhead is in the blue zone; tap/OK seeks past the segment; Auto skip intro works | ⬜ |

---

## Symptom

On ExoPlayer, IntroDB painted blue intro/recap seek zones (issue 517) but never showed the Skip Intro / Skip Recap floating chip. MediaKit did.

## Root cause

`ExoPlayerScreen` fetched IntroDB for seek-bar paint only. It never ran `_updateActiveSkipSegment`, never mounted `PlayerFloatingChip`, and never consumed `SettingsService.autoSkipIntroNotifier`. MediaKit mobile/desktop already did.

## Links

- [517](517-[fixed]-exo-introdb-seekbar-zones.md) — zones only
- [032](../032-[draft]-exoplayer-parity-gaps.md) — broader Exo parity tracker
