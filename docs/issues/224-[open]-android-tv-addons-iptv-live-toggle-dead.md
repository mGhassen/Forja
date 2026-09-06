# 224 — Android TV Addons IPTV / Live Sports toggle does not stick

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Addons · Android TV · `FocusableControl` · `sync_domain_bridge.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 2** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I224-A01 | ATV: Addons → focus IPTV / Live Sports switch → OK once → switch stays on; Features lists them; rail shows tabs | ⬜ |
| 2 | I224-A02 | Enable IPTV + Live Sports on web Profile → Features / Addons → open Addons on ATV → switches show on without local re-toggle | ⬜ |

---

## Summary

**Symptom:** On Android TV, OK on Addons IPTV / Live Sports switches did not leave them on. Features lacked those tabs. Cloud Profile could show them on while the app stayed off.

**Root cause:**

1. Leanback DPAD_CENTER Select often routed to Material `Switch` **ActivateIntent**. The switch used `onChanged: (_) {}` (enabled no-op) so OK looked dead — outer `FocusableControl.onTap` never flipped nav.
2. Soft pull on Addons open could overwrite a mid-pull local enable, or a dirty empty local gen could skip / fight cloud Features.
3. Early “flush dirty nav before pull” would intentionally overlay thin local and wipe richer cloud.

**After:** Leanback switch is display-only; `ActivateIntent` + key activate flip nav; soft pull skips stale apply when gen moved; thin dirty local yields to cloud; Addons force-pulls on open.

**Related:** [221](221-[open]-features-home-toggle-reverts-after-cloud-sync.md) · [126](126-[open]-android-tv-stale-settings-push-overwrites-cloud.md) · [222](222-[open]-android-tv-features-empty-after-pack-install.md)

## Verify

1. **Hot restart** ATV (`R` is not enough if isolate stale — prefer full stop/run).
2. Settings → Addons → → onto IPTV switch → OK once. Log should show `[AddonToggle] flip iptv OFF→ON` then `navbar iptv → true`.
3. Switch stays green; Features lists IPTV / Live Sports; rail shows tabs.
4. On web, turn them on → open Addons on ATV → switches match cloud.
