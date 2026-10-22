# 459 — Packs onboarding ignores cloud onboarded on new device

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** desktop · Android TV · packs onboarding · cloud sync  
**Reported:** 2026-10-22 (manual — Android TV install after desktop onboard)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Sign in on desktop, finish packs onboarding for a profile (`connectedServices.forja.onboarded: true` in `profile_settings`). Install Forja on Android TV, link the same account, pick the same profile on Who’s watching → packs wizard appears as if first-time, even though the profile is already onboarded in the cloud (and pack membership URLs are already on the profile).

## Root cause

`DesktopStartupGate._afterProfileReady` gates on `PacksOnboardingStore.shouldShow`, which reads **device-local** SharedPreferences only. Cloud `onboarded` is applied in `importForja` → `applyFromCloud` during ProfileSwitchSplash soft-pull — **after** the packs gate. Fresh installs have empty local prefs, so the wizard always shows. `importForja` also skips until profile disk scope is bound, so a full pull before the gate would not apply packs membership without `selectProfile` (by design — splash owns hydrate).

## Fix

Before `shouldShow`, soft-pull lean `profile_settings` for the picked profile id and apply only `forja.onboarded` into local prefs (`hydrateOnboardedFromCloud`). Pack scripts still hydrate on profile splash.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I459-T01 | `SyncService.pullProfileSettingsFor(profileId)` — lean payload without disk bind | ✅ |
| 2 | I459-T02 | `PacksOnboardingStore.hydrateOnboardedFromCloud` + apply with `profileId`; call from `_afterProfileReady` before `shouldShow` | ✅ |
| 3 | I459-T03 | Unit test for forja onboarded payload parse; changelog + feature copy | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I459-A01 | Desktop onboarded profile → new Android TV (or second desktop) after Who’s watching → **no** packs wizard when cloud `onboarded` is true | ⬜ |
| 2 | I459-A02 | Truly new / never-onboarded profile still shows packs wizard | ⬜ |

## Links

- [RFC-080](../rfc/fixed/080-[fixed]-post-login-packs-onboarding.md)
- [Issue 299](fixed/299-[fixed]-android-tv-profile-choice-focus-splash-delay.md) (handoff / profileId for shouldShow)
- [Cloud sync — Forja](../features/settings/cloud-sync.md)
