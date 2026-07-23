# 097 — Auto watched marks + series progress on details

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** playback / details (movies, anime, Asian Drama)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 6** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I97-T01 | Shared finished threshold = 85% (`watchFinishedThreshold` / resume window) | ✅ |
| 2 | I97-T02 | Auto-mark episode watched on ≥85% save (TMDB TV + anime + KissKh) | ✅ |
| 3 | I97-T03 | Details hero: series watched count / % (and Completed when 100%) | ✅ |
| 4 | I97-T04 | Details hero: movie finished shows Watched + check (via progress bar) | ✅ |
| 5 | I97-T05 | Keep manual right-click episode toggle | ✅ |
| 6 | I97-T06 | Manual QA — movie / TV / anime / Asian Drama details after finish | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I97-A01 | Finish an episode (≥85%) → check appears on details episode rail without manual toggle | ⬜ |
| 2 | I97-A02 | Series / anime / drama details show `N of T · %` (or Completed) from watched marks | ⬜ |
| 3 | I97-A03 | Movie details show Watched + check at ≥85%; Resume restarts from 0 | ⬜ |
| 4 | I97-A04 | Right-click still toggles watched / unwatched | ⬜ |

---

## Summary

Reuse `EpisodeWatchedService` + continue-watching progress. Auto-mark at **85%**. Details-only UI for series aggregate and movie finished check. No catalog badges, no Supabase sync for this slice.
