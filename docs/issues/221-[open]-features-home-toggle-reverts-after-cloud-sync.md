# 221 — Features Home toggle reverts after cloud sync

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Features · `sync_domain_bridge.dart` · web `sync-domains.ts` · profile_settings navigation

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I221-T01 | Await `setNavbarConfig` / default-tab write before `scheduleNavigationSyncPush` in Features UI | ✅ |
| 2 | I221-T02 | Skip cloud navigation apply while a local Features nav edit gen is unsynced | ✅ |
| 3 | I221-T03 | Soft pull refuse-shrink + heal push (landed, then superseded — fought web clears) | ✅ |
| 4 | I221-T04 | Navigation domain push is immediate (no 3s debounce) | ✅ |
| 5 | I221-T05 | Web `normalizeNavigationPayload` must not coerce empty `visibleIds` to all-on | ✅ |
| 6 | I221-T06 | Soft pull applies cloud Features when not dirty (revert T03 refuse-shrink heal) | ✅ |
| 7 | I221-T07 | Forja pack remove/purge pushes cloud immediately; purge path was missing schedule | ✅ |
| 8 | I221-T08 | Web Features lists host-core + opaque pack tab ids from cloud — no baked Home/Anime/… inventory | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I221-A01 | Enable Home in Features while signed in — toggle stays on after window focus / tab switch within a few seconds | ⬜ |
| 2 | I221-A02 | Web Profile → Features shows empty when cloud `visibleIds` is `[]`; turning tabs off saves and survives refresh | ⬜ |

---

## Summary

**Symptom:** User turns **Home** on in Settings → Features; a moment later the switch flips off. Web Profile → Features showed every tab on while the app had none. Deleting packs / clearing Features on web seemed not to stick.

**Root cause:**

1. Features saved navbar fire-and-forget then scheduled a push; soft pull flushed a stale empty `visibleIds` and poisoned cloud.
2. Soft pulls re-applied empty Features over local enables mid-edit.
3. **Web lie:** `normalizeNavigationPayload` coerced empty `visibleIds` to all tabs on — portal looked fully enabled; saving “all off” re-wrote all-on.
4. **Web inventory lie:** portal baked Home / Anime / Asian Drama / My List as known Features rows. Those are pack `nav` tabs — web must only show host-core (IPTV, Live Sports) plus opaque ids already in cloud.
5. Pack purge on device sometimes skipped `scheduleForjaSyncPush`.

**After:** Await Features writes; immediate navigation + Forja pack pushes; skip cloud nav apply only while a local Features edit is unsynced; web preserves empty Features; web Features is host-core + cloud pack tab ids only; pack remove/purge updates cloud.

**Related:** [126](126-[open]-android-tv-stale-settings-push-overwrites-cloud.md) · [099](099-[open]-profile-settings-cloud-master-local-cache.md)

## Verify

1. App: hot **restart** (`R`). Web: hard refresh Profile → Features.
2. Empty cloud → web shows **IPTV** + **Live Sports** (off) only — not a fake Home/Anime list.
3. After app syncs hub packs, those hub rows appear on web; toggle Home on in the app → stays on after tab switch / focus.
4. Turn tabs off on web → refresh → still off; app soft pull matches.
5. Remove a pack in the app → web Forja plugins list drops it after refresh.
