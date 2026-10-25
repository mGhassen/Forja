# 486 — Simkl auto sync lists when opening My List

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Simkl · My List · cross-device  
**Reported:** 2026-10-25 (desktop My List update not visible on TV)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Update My List on desktop (Simkl connected), open My List on TV — grid does not pick up the change. Background `fullSync` is history/CW only; list buckets only sync via Sync Now chooser. Watchlist RAM cache can also stay stale for ~10 minutes.

## Root cause (hypothesis until verified in code)

- `SimklService.fullSync` intentionally skips list buckets (`simkl_service.dart` — list stays Sync Now / connect only).
- Chosen Keep local / Use Simkl / Merge was not persisted for later auto use.
- No Settings gate for “sync lists when opening My List”.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I486-T01 | Persist list sync mode + auto-sync pref; `syncListBuckets` / `syncListsIfAuto` (2 min throttle) | ✅ |
| 2 | I486-T02 | Host bridge `host.simkl.syncListsIfAuto` + wipe feed cache after sync | ✅ |
| 3 | I486-T03 | My List pack calls sync before feed merge; bump pack version | ✅ |
| 4 | I486-T04 | Settings toggle; save mode from Sync Now / enable flow; feature + changelog | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I486-A01 | Settings → Simkl: enable Auto sync, pick Use Simkl → open My List on TV after desktop change → grid matches Simkl | ⬜ |
| 2 | I486-A02 | Auto sync off → opening My List does not run list import/export | ⬜ |
| 3 | I486-A03 | Status tab flips within ~2 min do not re-run full list sync (throttle) | ⬜ |

## Links

- [Simkl feature](../features/accounts/simkl.md)
- [My List](../features/movies-tv/my-list.md)
- [206](fixed/206-[fixed]-simkl-smart-sync-delta-cw-cap.md) (history smart sync — not list buckets)
