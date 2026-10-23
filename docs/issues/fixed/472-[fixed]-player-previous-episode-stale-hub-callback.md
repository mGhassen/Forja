# 472 — Player previous episode no-ops after next

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** desktop · mobile · exo · player episode transport  
**Reported:** 2026-10-23 (macOS MediaKit — Breaking Bad; next worked, previous did not)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

In the player, **Next Episode** loads the next episode. **Previous Episode** does nothing (no race, no toast) after at least one in-player episode switch — or whenever the hub callback’s captured `BuildContext` is already disposed.

## Root cause

`onHubEpisodeSelected` from `_hubEngineEpisodePicker` closes over the `BuildContext` of the route that opened / switched the player. `AppRouter.openPlayer` uses `pushAndRemoveUntil` and removes that player route. The callback then hits `if (!context.mounted) return` and exits silently.

**Next** on MediaKit desktop/mobile already used `_computeNextEpisode` → `_switchToEpisode` (live player context). **Previous** preferred the hub callback first — so next worked and previous did not.

Evidence: `desktop_player_episodes.dart` previous vs next; `engine_auto_play.dart` `_hubEngineEpisodePicker`; `app_router.dart` `openPlayer` replace.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I472-T01 | Desktop + mobile previous: same path as next (`_computePreviousEpisode` → `_switchToEpisode`) | ✅ |
| 2 | I472-T02 | Exo previous / next hub + Episodes panel: `_switchToEpisode` with live player context | ✅ |
| 3 | I472-T03 | Desktop + mobile Episodes panel: always `_switchToEpisode` (drop stale hub callback) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I472-A01 | After Next Episode, Previous Episode races and opens the prior episode (macOS MediaKit) | ⬜ |
| 2 | I472-A02 | Exo: previous and Episodes panel pick still switch after one next | ⬜ |

## Links

- Related: [453](453-[fixed]-airplay-drops-on-next-episode.md) (next-episode handoff)
