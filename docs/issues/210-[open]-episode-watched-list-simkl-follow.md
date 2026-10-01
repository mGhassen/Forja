# 210 — Episode watched toggle does not update My List / Simkl lists

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** lists / trackers (details episode rail)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 7** fix · **0 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I210-T01 | Shared `ListFollowFromWatched` — Watching on first mark, Completed when all marked | ✅ |
| 2 | I210-T02 | TMDB / Anime / Asian Drama details toggle (+ double-click) apply list follow + invalidate Simkl lists | ✅ |
| 3 | I210-T03 | Player ≥85% auto-mark applies the same list follow | ✅ |
| 4 | I210-T04 | Keep existing Trakt/Simkl **history** sync for episode marks | ✅ |
| 5 | I210-T05 | Double-click / right-click season poster toggles all aired episodes in that season | ✅ |
| 6 | I210-T06 | Manual QA — mark / unmark / finish series on Lists + Simkl | ⬜ |
| 7 | I210-T07 | Completed only with declared series total — never invent from current ep / partial `videos[]` (false Completed after E1) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I210-A01 | Right-click or double-click episode → local checkmark; show moves to Watching (or adds) when new / Plan to Watch | ⬜ |
| 2 | I210-A02 | Marking the last episode → Completed on My List and Simkl list bucket when logged in | ⬜ |
| 3 | I210-A03 | Unmarking while Completed → Watching; episode history still syncs to Simkl/Trakt | ⬜ |
| 4 | I210-A04 | Double-click season poster marks every aired episode in that season (toggle off when all marked) | ⬜ |
| 5 | I210-A05 | Finishing episode 1 of a multi-ep series → Watching (or stays Watching), never Simkl/My List Completed | ⬜ |

---

## Summary

Episode toggle only wrote local checkmarks + tracker **history**. Lists tabs and Simkl **library status** (Watching / Completed) never moved. Wire list follow from the same marks (manual + auto ≥85%, season bulk toggle).

**Regression (I210-T07):** auto-mark used `meta.episodes ?? ep` and `videos.length` as the series total, so finishing E1 (or any play with a one-row video list) set Simkl/My List to **Completed**. Completed now requires a declared total (`MetaItem.episodes` / `facts.episodeCount` / TMDB `number_of_episodes`); unknown total → Watching only.