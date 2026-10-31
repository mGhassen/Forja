# 500 — Simkl list status: silent rewrite + film mediaType + remove hide

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Simkl · My List · list status  
**Reported:** 2026-10-26 (completed on airing show; film status; remove toast but poster stays)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. Marking a still-airing series Completed — Forja shows Completed; Simkl stays Watching; no feedback.
2. Changing a film’s list status often does not update the Simkl movie.
3. Remove from My List shows success toast but Simkl-backed poster stays in the grid.

## Root cause

1. `POST /sync/add-to-list` returns 201 and silently rewrites `completed` → `watching` for airing shows. Forja only checked HTTP ok.
2. `ListFollow.setStatus` used `mediaType: tmdbMediaType ?? 'tv'` — films with null `tmdbMediaType` sent as shows.
3. Hide keys on remove used catalog `uniqueId` only; My List Simkl cards key on `open:anime:…` / `open:tmdb:…`. `retainOnlyPresentIn` then dropped the useless hide key and the row stayed.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I500-T01 | Parse add-to-list `added.*.to`; rewrite local + toast when downgraded | ✅ |
| 2 | I500-T02 | Resolve Simkl mediaType via normalize(tmdbMediaType \|\| resolved) | ✅ |
| 3 | I500-T03 | Hide keys = open/tmdb/anilist; clear Simkl watchlist cache on remove | ✅ |
| 4 | I500-T04 | Unit tests + changelog | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I500-A01 | Airing show → Completed → toast + local Watching (matches Simkl) | ⬜ |
| 2 | I500-A02 | Remove series from Completed → poster gone; film status hits Simkl movie | ⬜ |

## Links

- [Simkl add-to-list silent rewrites](https://api.simkl.org/api-reference/simkl/add-to-list)
- [497](497-[fixed]-simkl-merge-with-deletion.md)
- Follow-on film wipe: [520](520-[fixed]-simkl-movie-list-status-wiped-by-history-remove.md)
