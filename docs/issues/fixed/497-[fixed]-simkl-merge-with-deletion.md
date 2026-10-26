# 497 — Simkl Merge + delete list sync mode

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Simkl · My List · list sync  
**Reported:** 2026-10-26 (Merge re-imports titles the user deleted in Forja)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

With **Merge**, deleting a series in Forja does not stay deleted across Sync Now if it is still on Simkl — import writes it back. Users want merge that still pulls new Simkl titles, but keeps explicit Forja deletes off Simkl and off the local mirror.

## Root cause

`syncListBuckets(merge)` only exported remaining bookmarks then imported the full Simkl library. No tombstones; list export never sent removals. Live `removeFromWatchlist` on UI delete could lag or fail; Merge still resurrected.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I497-T01 | Add `mergeWithDeletion` mode + storage round-trip | ✅ |
| 2 | I497-T02 | Device-local delete tombstones; flush + import skip | ✅ |
| 3 | I497-T03 | Record/clear tombstones from ListFollow + movie status pins | ✅ |
| 4 | I497-T04 | Settings label/toast; feature + changelog; web mode comment | ✅ |
| 5 | I497-T05 | Unit tests for mode parse + import skip | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I497-A01 | Merge + delete: delete in Forja → Sync Now → title gone on Simkl and not re-imported | ⬜ |
| 2 | I497-A02 | Merge + delete: new Simkl-only title still imports; plain Merge unchanged | ⬜ |

## Links

- [486](../486-[open]-simkl-auto-sync-lists-on-my-list-open.md)
- [492](492-[fixed]-simkl-list-sync-prefs-cloud-profile.md)
- [Simkl feature](../../features/accounts/simkl.md)
