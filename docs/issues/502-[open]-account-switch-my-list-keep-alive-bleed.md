# 502 — Account switch leaves previous My List on keep-alive UI

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** Android TV · Account · My List · isolation  
**Reported:** 2026-10-27 (manual ATV release: Switch account → My List still shows prior account)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On released Android TV: Switch Account A → B, open My List — B still sees A’s titles. Cross-account data bleed (isolation breach).

## Root cause

Verified in code:

- `LocalDataScope` + `BookmarkStore` already isolate disk prefs per `accountId:profileId` and reload RAM on configure.
- `SyncService._syncPluginDiskScope` rebound disk but **never** busted process-RAM hub UI: `EngineCache` `feed` entries and keep-alive `PackLayoutPainter` (listens to `listFeedEpoch` / hub epoch, not identity).
- `invalidateListHubFeeds` / `bumpHubFeedEpoch` were only called on list writes / pack reload — not on account or profile switch.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I502-T01 | After identity-changing `_syncPluginDiskScope`, call `bustIdentityBoundHubUiCaches()` (wipe feed + clear hide-keys + bump all hubs clear-paint-on-open) | ✅ |
| 2 | I502-T02 | Unit test: feed cache gone + list epoch bumped + hub reload-on-open after bust | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I502-A01 | ATV: account A My List populated → switch to B → My List empty or B-only (no A titles) | ⬜ |
| 2 | I502-A02 | Switch back to A → A’s My List restored from A’s scoped cache | ⬜ |

## Links

- [499](499-[open]-multi-account-session-switch.md) — switch shipped; prefs-per-account acceptance still open
- [467](467-[open]-cross-account-simkl-connected-secrets-isolation.md) — Simkl / secrets isolation (logout→login)
- [RFC-082](../rfc/082-[open]-account-profile-local-data-scope.md)
