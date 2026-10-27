# 509 — Anime season switch leaves My List pin on prior cour

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** anime · details · My List  
**Reported:** 2026-10-28 (manual — Slime S4 pin stuck after season chip)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On multi-cour anime details, switching Season / OVA chips updates hero art and episodes, but the My List pin (watching / completed / …) stays on the previous cour’s status.

## Root cause

1. Soft season stub used `MetaItem.copyWith` and cleared art/videos but kept prior `open` / `id` / TMDB `ids` — hero `ListFollowTarget.uniqueId` stayed on the old AniList Media (`pack_details_host` season switch).
2. Hero pin read `BookmarkStore.resolvedStatus` (TMDB alias). Sibling cours often share franchise TMDB → prior cour status painted after load too.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I509-T01 | Soft season stub = fresh MetaItem with new `open`/`id` (no prior ids) | ✅ |
| 2 | I509-T02 | Anime hero pin skips TMDB alias (`tmdbId: null` when surface/mediaType anime) | ✅ |
| 3 | I509-T03 | `ValueKey(uniqueId)` on hero pin; close menu when uid changes | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I509-A01 | Pin season A watching → switch to unpinned season B → pin idle / not watching | ⬜ |
| 2 | I509-A02 | Pin season B completed → switch back to A → shows watching again | ⬜ |

## Links

- [098](../098-[open]-anime-details-season-chain.md) — season chain / soft switch
- [448](448-[fixed]-my-list-kind-filter-and-pin-state.md) — poster exact→known→loose pin (hero was still TMDB-aliased)
