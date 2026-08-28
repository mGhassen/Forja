# 211 — Movie play does not update My List / Simkl pin

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** lists / trackers (movie playback)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I211-T01 | `ListFollowFromWatched` movie helpers — Watching on play, Completed ≥85%, reconcile from progress | ✅ |
| 2 | I211-T02 | Desktop / mobile / Exo player start → Watching (local + Simkl) | ✅ |
| 3 | I211-T03 | Player progress save ≥85% → Completed | ✅ |
| 4 | I211-T04 | Details open with movie progress reconciles pin | ✅ |
| 5 | I211-T05 | Manual QA — play / finish film; pin + Lists + Simkl | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I211-A01 | Play a movie not on My List → pin shows Watching; Lists Watching; Simkl when logged in | ⬜ |
| 2 | I211-A02 | Reach ≥85% → pin / Lists / Simkl move to Completed | ⬜ |
| 3 | I211-A03 | Reopen details with mid-watch progress and empty pin → Watching without re-play | ⬜ |

---

## Summary

Watch history saved on movie play (resume bar), but My List pin and Simkl **list buckets** were manual-only. Anime/drama already call `markWatchingOnPlay`; TV episodes follow via issue 210. Movies only scrobbled — scrobble ≠ list status. Wire Watching on play start and Completed at the same ≥85% finish threshold as episodes.
