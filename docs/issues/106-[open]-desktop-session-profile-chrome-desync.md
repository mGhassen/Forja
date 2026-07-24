# 106 — Desktop long-idle session / profile chrome desync

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/sync/` · `app/bootstrap.dart` · Who’s watching · Settings Profile & account · About updater  
**Reported:** 2026-07-24

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I106-T01 | Desktop session keep-alive (periodic refresh) + window focus/restore refresh | ✅ |
| 2 | I106-T02 | `listProfiles` / access-token skew timeout; throw `SyncProfileFetchException` (no silent `[]`) | ✅ |
| 3 | I106-T03 | Who’s watching + Settings Profile error + Retry (no fake “create profile” / stale Synced) | ✅ |
| 4 | I106-T04 | Rail avatar keeps last profile on failed reload (no stuck Guest while signed in) | ✅ |
| 5 | I106-T05 | About Check for Updates — failed check is an error toast, not “latest version” | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I106-A01 | Mac left open hours: session still refreshes; rail shows active profile name when signed in | ⬜ |
| 2 | I106-A02 | Forced profile API hang/timeout → Who’s watching shows error + Retry (not infinite spinner / create copy) | ⬜ |
| 3 | I106-A03 | About with CDN down / bad manifest → error toast (never “You’re running the latest version!”) | ⬜ |

---

## Summary

After leaving the Mac app open a long time, the rail could show **Guest** while Settings still showed **Streaming / Synced / email**, and **Who’s watching** spun forever with “Create a profile…” copy. Hard `signedOut` (issue 085) was not always the path — soft-fail hangs and chrome that only listens to `identityRevision` left a split UI.

**Root (host):** macOS windows often stay `resumed` so lifecycle refresh never runs; `listProfiles` had no timeout and swallowed errors as `[]`; rail cleared profile chrome before reload finished; About treated every `null` update check as up-to-date.

**Related:** [085](085-[open]-desktop-involuntary-signout-dumps-login.md) (hard sign-out wipe) · [RFC-042](../rfc/042-[open]-unified-auth-system.md)
