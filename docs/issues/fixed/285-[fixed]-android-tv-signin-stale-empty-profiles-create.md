# 285 — Android TV sign-in opens Add profile despite existing profiles

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** account / Who's watching / Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0/2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I285-T01 | Guard auto-create: only on settled empty; show loading for empty+reloading | ✅ |
| 2 | I285-T02 | Revert auto-opened create → Who's watching when profiles arrive; manual Add unaffected | ✅ |
| 3 | I285-T03 | Changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I285-A01 | ATV: sign out → sign in on account with profiles → Who's watching (not Add profile) | ⬜ |
| 2 | I285-A02 | New account with zero profiles still opens Create your profile after load | ⬜ |

---

## Summary

After TV device-link sign-in on an account that already had profiles, Who's watching auto-jumped to **Add profile**. Title was "Add profile" (not "Create your profile") because the real list arrived after the jump.

**Root:** `listProfiles()` returns `[]` when signed out. That empty snap stayed as `valueOrNull` while the post–sign-in reload was in flight. Profile chooser treated any empty snap as “no profiles yet” and forced `_Screen.create`, with no path back when profiles loaded.

**Root fix:** Auto-create only when the provider is settled (not loading / not error). Empty+loading shows the spinner. Auto-open is flagged; if profiles arrive, return to Who's watching. Manual Manage → Add profile does not set that flag.

## Related

- `apps/forja/lib/features/account/profile_chooser_screen.dart`
- `apps/forja/lib/shared/sync/providers/sync_profiles_provider.dart`
- [109](109-[open]-android-tv-boot-jwt-expired-discard-race.md)
