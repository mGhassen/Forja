# 221 — Features Home toggle reverts after cloud sync

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Features · `sync_domain_bridge.dart` · profile_settings navigation

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I221-T01 | Await `setNavbarConfig` / default-tab write before `scheduleNavigationSyncPush` in Features UI | ✅ |
| 2 | I221-T02 | Skip cloud navigation apply while a local Features nav edit gen is unsynced | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I221-A01 | Enable Home in Features while signed in — toggle stays on after window focus / tab switch within a few seconds | ⬜ |
| 2 | I221-A02 | Cloud `visibleIds` gains `home` after the debounced navigation push (not overwritten by empty pull) | ⬜ |

---

## Summary

**Symptom:** User turns **Home** on in Settings → Features; a moment later the switch flips off and the rail stays empty (get-started), even though the ForjaHQ Home pack remains installed and enabled.

**Root cause:** Features saved navbar with a **fire-and-forget** `setNavbarConfig` then immediately `scheduleNavigationSyncPush()`. Window focus / tab select runs `syncFromCloud`, which flushes the pending navigation overlay. If KV write had not finished, the export still had empty `visibleIds`, pushing empty Features to cloud and pulling that empty set back over the local toggle. Same class as [126](126-[open]-android-tv-stale-settings-push-overwrites-cloud.md) (stale nav vs cloud), inverted: thin cloud wins over a just-written local enable.

**After:** Features awaits the KV write before scheduling the push. Pulls skip applying `payload.navigation` while a local navigation edit generation is ahead of the last successful navigation push.

**Related:** [126](126-[open]-android-tv-stale-settings-push-overwrites-cloud.md) · [099](099-[open]-profile-settings-cloud-master-local-cache.md)

## Verify

1. Signed in, Home pack enabled, Features Home off → turn Home **on**.
2. Immediately click another tab or refocus the window.
3. Features Home stays on; rail shows Home; cloud profile settings `navigation.visibleIds` includes `home`.
