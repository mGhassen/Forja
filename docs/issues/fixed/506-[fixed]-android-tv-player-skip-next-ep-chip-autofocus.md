# 506 — Android TV player Skip / Next Episode chips take focus when they appear

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Android TV · player chrome · floating chips  
**Reported:** 2026-10-28 (remote: chips pop without D-pad landing on them)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Android TV, when **Skip Intro** / **Skip Recap** / **Skip Credits** / **Skip Preview** or **Next Episode** appears, the remote stays on Play / the video key scope. The user must D-pad to the chip manually.

## Root cause

`PlayerTvKeyScope` only reclaim-focused the floating chip while chrome was **hidden** and `floatingChipVisible` flipped or focus was lost. Chip **appearance** while chrome was up (or when Skip was already visible and Next Episode joined) did not request focus on the new chip.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I506-T01 | Schedule D-pad claim when Skip segment or Next Episode chip appears (MediaKit TV + Exo) | ✅ |
| 2 | I506-T02 | Widget test: host can park focus on Next Episode while chrome is visible | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I506-A01 | ATV: Skip Intro / Recap / Credits appears → focus on that chip (unless Auto skip fires) | ⬜ |
| 2 | I506-A02 | ATV: Next Episode appears (chrome up or hidden) → focus on the chip; → reaches countdown X | ⬜ |

## Links

- [RFC-122](../../rfc/122-[draft]-android-tv-remote-ux.md)
- [player.md](../../features/playback/player.md) · [next-episode.md](../../features/playback/next-episode.md)
