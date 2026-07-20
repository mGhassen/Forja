# 085 — Desktop involuntary sign-out dumps to login mid-use

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `app/desktop_startup_gate.dart` · `shared/sync/` · gotrue  
**Reported:** 2026-07-19

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance (manual smoke) · **1 / 1** superseded |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I85-T01 | `shouldReturnToAccountOnSignOut` — only `userInitiated` destroys shell while in app | ✅ |
| 2 | I85-T02 | Log auth events + `signOutReason`; keep shell on `sessionExpired` / `sessionMissing` | ✅ |
| 3 | I85-T03 | Clear account features + cancel sync pushes without tearing down navigation | ✅ |
| 4 | I85-T04 | Reverse keep-shell: every `signedOut` returns to Account entry (security) | ✅ |
| 5 | I85-T05 | Wipe account-bound local state on sign-out (IPTV portals, prefs, alive/channel caches) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I85-A01 | Mid-playback involuntary `signedOut` keeps player/shell — no Account entry screen | ⏭️ |
| 2 | I85-A02 | Explicit Sign out from Settings / Who’s watching still returns to Account entry | ⬜ |
| 3 | I85-A03 | Involuntary `signedOut` returns to Account entry; IPTV portals / Guest must not keep prior account portals | ⬜ |

---

## Summary

`DesktopStartupGate` treated every `AuthChangeEvent.signedOut` as a hard boot to `AccountEntryScreen`. gotrue emits that event when a refresh token is rejected (`SignOutReason.sessionExpired`) — e.g. refresh rotation while the web portal is also signed in, or a non-retryable auth API error. That wiped the running app (player → login) even though the user never signed out.

**Historical symptom fix (I85-T01–T03):** keep the app shell on involuntary loss; re-auth from Settings. That left **Guest** chrome with prior account IPTV portals still loaded — a security leak.

**Current policy (I85-T04–T05):** any `signedOut` returns to Account entry and wipes account-bound local state (`SyncDomainBridge.clearAccountBoundLocalState` — IPTV portals/passwords, favorites, last portal, alive/channel caches, synced prefs to platform defaults). Explicit sign-out and involuntary session loss share that path. `I85-A01` superseded by `I85-A03`.

**Root (tokens):** gotrue still clears the local session when refresh fails. Concurrent web + desktop sessions with refresh-token rotation remain a likely server-side cause.
