# 224 — Android TV Addons IPTV / Live Sports toggle does not stick

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Addons · Android TV · `FocusableControl` · `sync_domain_bridge.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **37 / 37** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I224-T01 | Leanback `FocusableControl`: key-only activate (no `GestureDetector.onTap`) so DPAD_CENTER Select+click cannot flip twice | ✅ |
| 2 | I224-T02 | Lengthen activate coalesce; nav push schedules without blocking the toggle UI | ✅ |
| 3 | I224-T03 | Soft pull: never flush dirty thin nav over cloud; apply cloud when dirty local would shrink Features | ✅ |
| 4 | I224-T04 | Opening Settings → Addons `syncFromCloud(force: true)` so cloud-enabled IPTV / Live Sports apply | ✅ |
| 5 | I224-T05 | Skip nav apply when local gen moved during an in-flight soft pull | ✅ |
| 6 | I224-T06 | Leanback Addons switch: `onChanged: null` + `ActivateIntent` → flip (Material Switch was swallowing Select as no-op) | ✅ |
| 7 | I224-T07 | Keep Settings visibility across reload so Addons body is not remounted mid-toggle | ✅ |
| 8 | I224-T08 | Serialize navbar RMW (`setNavbarTabVisible`) so rapid IPTV then Live Sports OK cannot wipe the first write | ✅ |
| 9 | I224-T09 | `noteNavigationDirty()` before navbar KV write so Addons soft-pull cannot apply empty cloud mid-enable | ✅ |
| 10 | I224-T10 | Addons/Features/Packs: row OK activates; details chevron on the right; Features D-pad uses per-row `TvCatalogRow` columns | ✅ |
| 11 | I224-T11 | Row activate calls `setAddonMasterEnabled` directly (no mid-build `_flip` callback — silent no-op) | ✅ |
| 12 | I224-T12 | Soft pull refuses cloud nav that shrinks local tabs; heal hollow cloud with a nav push | ✅ |
| 13 | I224-T13 | Features toggles use `setNavbarTabVisible` RMW + serialize saves; skip hydrate mid-write | ✅ |
| 14 | I224-T14 | Dirty soft pull: apply richer cloud only when local visible is empty — never replace non-empty Addons enables | ✅ |
| 15 | I224-T15 | Session navbar memory heal + serialize IPTV/Live Sports addon toggles through sync push | ✅ |
| 16 | I224-T16 | Stop Features/hub refresh from re-inserting every hub after intentional all-hub hide (Home enable was no-op / no rail) | ✅ |
| 17 | I224-T17 | MainScreen navbar load generation guard — stale async reload cannot wipe a newer visible set | ✅ |
| 18 | I224-T18 | RFC-086: Addons write `addon_feature_*` only; Features sole `visibleIds` writer | ✅ |
| 19 | I224-T19 | RFC-086: packs `ensureNavIdsKnown` known-only (no first-seen auto-insert into navbar) | ✅ |
| 20 | I224-T20 | Soft pull skips `addon_feature_*` while local dirty; prefs push immediate for pending Addons enable (cloud false no longer snaps IPTV/Live off) | ✅ |
| 21 | I224-T21 | Web Addons writes `addon_feature_*` + rail; app heals legacy nav-only cloud; Features lists IPTV/Live only when unlocked | ✅ |
| 22 | I224-T22 | Derived Features inventory (flags ∪ pack hubs); stop HOST_CORE bake-in; prune nav on pack remove | ✅ |
| 23 | I224-T23 | Prefs overlay omits `addon_feature_*` unless intentional Addons push; remove dirty-gen / soft-pull skip / heal stack | ✅ |
| 24 | I224-T24 | Soft pull awaits nav heal when local rail is richer; Addons push flags + nav in one overlay (web Features rail matches app) | ✅ |
| 25 | I224-T25 | Web Addons IPTV / Live: one `profile_settings` patch (playback flags + nav) so Features prune cannot drop the just-enabled tab | ✅ |
| 26 | I224-T26 | Web Features hydrates inventory from cloud playback/packs (not empty playDraft); default-on never-stored available ids | ✅ |
| 27 | I224-T27 | Web pack install default-on hub Features (`navigationAfterForjaPacksChange`); Features hydrate without inventory prune; cache set on save | ✅ |
| 28 | I224-T28 | Pack hub refresh must not put Features `visibleIds` into `syncActiveHubNavIds` known set (stripped Anime ON from rail); MainScreen listens KV notifier directly; rail fallback dest; pack-prompt activates hubs | ✅ |
| 29 | I224-T29 | Stop navbar notify storm: no mid-refresh cache bump; Features scan bumps only on changed; `ensureNavIdsKnown` known-only (no visible auto-insert); MainScreen debounce + no-op skip | ✅ |
| 30 | I224-T30 | Hub refresh: do not fold Features `visibleIds` into `syncActiveHubNavIds` known on the live path; scripts-missing = hydration pending; skip empty-active strip unless intentional wipe; Features heal re-enable after strip race | ✅ |
| 31 | I224-T31 | MainScreen must not filter Features tabs with `isContributed` (silent rail drop); hub refresh must not empty-active-strip when packs exist; Features toggle forces rail notify | ✅ |
| 32 | I224-T32 | Radical: no soft-pull on Features open; no routine hub sync strip on refresh; refuse dirty `_importNavigation` shrink; Features skip hydrate that drops tabs; pack OFF explicitly hides hubs; navbar write stack logs | ✅ |
| 33 | I224-T33 | Soft pull never applies empty `visibleIds` (refuse `_importNavigation` + skip hollow cloud); seeded `getNavbarConfig` read-only (no silent shell migration wipe); `setNavbarTabVisible` readback under exclusive lock | ✅ |
| 34 | I224-T34 | Soft pull: when synced, cloud is SoT (web enables land); flush dirty nav push before pull; skip nav apply only while local edit unsynced — remove refuse-empty/shrink that blocked cloud→app | ✅ |
| 35 | I224-T35 | Session navbar + crash-reporting memory SoT when KV readback no-ops; refuse hollow `[]` nav push over rich cloud; drop dirty-hollow take-cloud; loud `[KV] skipped` when `!Engine.isReady` | ✅ |
| 36 | I224-T36 | Android: ship `libc++_shared.so` next to `libffi.so` (dlopen was failing → Engine never ready → all settings writes no-op) | ✅ |
| 37 | I224-T37 | Features first hide: ignore stale richer provider snap; drop one-way “skip hydrate that drops tabs” that then blocked the correct thinner snap | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I224-A01 | ATV: Addons → OK on IPTV / Live Sports → switch stays on; Features lists them; rail shows by default | ⬜ |
| 2 | I224-A02 | Enable IPTV + Live Sports on web Profile → Features / Addons → open Addons on ATV → switches show on without local re-toggle | ⬜ |
| 3 | I224-A03 | Features can hide IPTV / Live while Addons stays on; Addons OFF removes both Features inventory and rail | ⬜ |
| 4 | I224-A04 | ATV: Features → OK on a hub tab (e.g. Anime) → switch stays on and shell rail shows that tab (profile avatar alone is not enough) | ⬜ |

---

## Summary

**Symptom:** On Android TV, OK on Addons IPTV / Live Sports switches did not leave them on. Features lacked those tabs. Cloud Profile could show them on while the app stayed off. Web Features listed IPTV / Live / hub tabs when Addons were off and Packs empty.

**Root cause:**

1. Leanback DPAD_CENTER Select often routed to Material `Switch` **ActivateIntent**. The switch used `onChanged: (_) {}` (enabled no-op) so OK looked dead — outer `FocusableControl.onTap` never flipped nav.
2. Soft pull on Addons open could overwrite a mid-pull local enable, or a dirty empty local gen could skip / fight cloud Features.
3. Early “flush dirty nav before pull” would intentionally overlay thin local and wipe richer cloud.
4. Rapid OK on IPTV then Live Sports raced `getNavbarConfig` → mutate → `setNavbarConfig` — both reads saw `[]`, second write left only `live_matches` (logs: `next=[iptv]` then `next=[live_matches]`).
5. After RFC-086, Addons writes `addon_feature_*` in **preferences** while opening Addons force soft-pulls playback — a full local playback replace on any prefs push uploaded `addon_feature_*=false` and wiped richer cloud.
6. Web Profile → Addons IPTV / Live only mutated `navigation.visibleIds` — never `addon_feature_*` — so cloud “ON” never unlocked the app switch / Features inventory.
7. Web `normalizeNavigationPayload` always injected HOST_CORE into `tabOrder`, so Features listed IPTV / Live even when unlocked flags were false; stale hub ids stayed after packs were cleared.
8. Web Addons toggled flag + nav via two parallel commits; nav `toPayload` pruned with **old** `availableIds` (flags still false) and stripped the tab just enabled.
9. Web Features hydrated nav by pruning against **empty** `playDraft` (effects not run yet) — cloud `visibleIds` for IPTV/Live were stripped so Features showed the row OFF or empty after Addons ON.
10. Pack hub `PluginNavRegistry.refresh` folded Features `visibleIds` into `syncActiveHubNavIds` **knownHubIds**, so a mid-refresh empty active set **stripped** just-enabled hub tabs from KV (Features Anime ON, shell rail only profile).
11. `_syncHubNavVisibility` re-introduced that fold for “legacy ghosts”; with scripts still awaiting confirm, empty-active sync stripped Anime right after Features OK (A04).
12. Soft pull kept applying cloud `visibleIds=[]` while fighting mid-edit enables; later refuse-empty/shrink guards then blocked **cloud → app** so web Features/Addons never landed.
13. **Android emulator / ATV root (224 logs):** `libffi.so` dlopen failed — `libc++_shared.so` not packaged in jniLibs → `Engine.isReady=false` → every KV write silently no-op’d (`navbar write []→[anime]` then readback `[]`; crash toggle stuck on fallback).

**After:** Leanback switch is display-only; row OK calls `setAddonMasterEnabled`; soft pull applies cloud `addon_feature_*` as authority; ordinary prefs pushes merge playback but **omit** unlock flags unless `scheduleAddonFeaturesSyncPush`; Features inventory is derived (flags ∪ pack hubs) on web and app; pack remove prunes nav; Addons force-pulls on open without demoting cloud unlocks via stale prefs flush; web Addons IPTV / Live writes flags + rail in **one** `patch`; web Features hydrates from cloud playback flags (not empty draft); hub refresh known-set is pack-installed only on the live path (orphans only on no-packs wipe); scripts-missing counts as hydration pending; Features re-enables if a strip race still lands; soft pull **flushes dirty nav push first**, then applies **cloud as SoT when synced** (web enables land); skips nav apply only while a local edit is still unsynced; Android jniLibs ships **`libc++_shared.so`** with `libffi.so`; session navbar/crash memory covers transient KV miss.

**Related:** [221](221-[open]-features-home-toggle-reverts-after-cloud-sync.md) · [126](126-[open]-android-tv-stale-settings-push-overwrites-cloud.md) · [222](222-[open]-android-tv-features-empty-after-pack-install.md)

## Verify

1. **Full stop + `flutter run`** (must reinstall APK so `libc++_shared.so` is in the package). Boot log must show `Rust engine v…` — not `libc++_shared.so not found`.
2. Settings → Addons → focus IPTV row → OK once. Log must show `[AddonToggle] set iptv → true`.
3. Switch stays green; Features lists IPTV / Live Sports; rail shows tabs by default.
4. OK again turns off and stays off; Features drops the row (not merely toggle off).
5. Web: Addons OFF + Packs empty → Features shows Settings only (no IPTV / Live / Asian Drama rows).
6. Web IPTV ON → open Addons on ATV → switch on. Changing EPG / quality on ATV must not clear cloud IPTV unlock.
