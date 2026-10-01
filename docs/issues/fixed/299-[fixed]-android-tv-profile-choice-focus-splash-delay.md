# 299 — Android TV Who’s watching focus jump + splash delay

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** account / Who's watching / Android TV / profile splash

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0/2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I299-T01 | Busy profile tiles use IgnorePointer (keep focus) — not ExcludeFocus | ✅ |
| 2 | I299-T02 | Cold pick hands off profile immediately; splash owns select + merge | ✅ |
| 3 | I299-T03 | `selectProfile(skipRemoteCheck:)` skips listProfiles before splash paint | ✅ |
| 4 | I299-T04 | Changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I299-A01 | ATV: OK on a non-active profile — highlight stays on that avatar until splash | ⬜ |
| 2 | I299-A02 | ATV: after sign-in, OK a profile → avatar splash starts without a long dead Who’s watching pause | ⬜ |

---

## Summary

On Android TV, OK on a Who’s watching avatar moved the white ring to the **other** (active/autofocus) profile, then the screen sat idle for a long time before the avatar splash.

**Root (focus):** `_busy = true` set every tile `ExcludeFocus(excluding: true)`, ripping focus off the pressed tile; rebuild autofocus landed on `autofocusIndex` (active profile).

**Root (delay):** Cold gate `useLogoIntroSplash` awaited `selectProfile` + full `pullAndMergeForProfileSwitch` on the chooser (and `selectProfile` always called `listProfiles()` over the network) before showing splash — which then did select + merge again.

**Root fix:** IgnorePointer while busy (focus stays). Handoff the picked `SyncProfile` immediately; packs onboarded check uses that profile id; splash owns select/merge. `selectProfile(skipRemoteCheck: true)` when the picker already supplied the profile.

## Related

- `apps/forja/lib/features/account/profile_chooser_screen.dart`
- `apps/forja/lib/app/desktop_startup_gate.dart`
- `apps/forja/lib/features/account/profile_switch_splash.dart`
- `apps/forja/lib/shared/sync/api/sync_service.dart`
- [285](285-[fixed]-android-tv-signin-stale-empty-profiles-create.md)
