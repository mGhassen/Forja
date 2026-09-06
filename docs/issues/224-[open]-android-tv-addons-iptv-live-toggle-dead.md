# 224 — Android TV Addons IPTV / Live Sports toggle does not stick

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Addons · Android TV · `FocusableControl` · `sync_domain_bridge.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **13 / 13** fix · **0 / 2** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I224-A01 | ATV: Addons → OK on IPTV / Live Sports row once → switch stays on; chevron opens details; Features lists them; rail shows tabs | ⬜ |
| 2 | I224-A02 | Enable IPTV + Live Sports on web Profile → Features / Addons → open Addons on ATV → switches show on without local re-toggle | ⬜ |

---

## Summary

**Symptom:** On Android TV, OK on Addons IPTV / Live Sports switches did not leave them on. Features lacked those tabs. Cloud Profile could show them on while the app stayed off.

**Root cause:**

1. Leanback DPAD_CENTER Select often routed to Material `Switch` **ActivateIntent**. The switch used `onChanged: (_) {}` (enabled no-op) so OK looked dead — outer `FocusableControl.onTap` never flipped nav.
2. Soft pull on Addons open could overwrite a mid-pull local enable, or a dirty empty local gen could skip / fight cloud Features.
3. Early “flush dirty nav before pull” would intentionally overlay thin local and wipe richer cloud.
4. Rapid OK on IPTV then Live Sports raced `getNavbarConfig` → mutate → `setNavbarConfig` — both reads saw `[]`, second write left only `live_matches` (logs: `next=[iptv]` then `next=[live_matches]`).

**After:** Leanback switch is display-only; row OK calls `setAddonMasterEnabled` (no mid-build flip callback); soft pull skips stale apply when gen moved and refuses cloud nav that shrinks local tabs; thin dirty local yields to richer cloud; Addons force-pulls on open; navbar RMW is serialized; Addons/Features/Packs share row-activate + details-chevron; Features D-pad keeps column via `TvCatalogRow`.

**Related:** [221](221-[open]-features-home-toggle-reverts-after-cloud-sync.md) · [126](126-[open]-android-tv-stale-settings-push-overwrites-cloud.md) · [222](222-[open]-android-tv-features-empty-after-pack-install.md)

## Verify

1. **Hot restart** ATV / desktop (`R` is not enough if isolate stale — prefer full stop/run).
2. Settings → Addons → focus IPTV row → OK once. Log must show `[AddonToggle] flip iptv OFF→ON` then `set iptv → true` / `navbar iptv → true`.
3. Switch stays green; → chevron → OK opens details; Features lists IPTV / Live Sports; rail shows tabs.
4. Features: ↓ on a tab label moves to the next tab; ↓ on star moves to the next row’s star. Toggle stays after leaving Settings.
5. Soft pull must log `skip cloud nav shrink` when cloud is thinner — not wipe local enables.
6. On web, turn them on → open Addons on device → switches match cloud (cloud richer still applies).
