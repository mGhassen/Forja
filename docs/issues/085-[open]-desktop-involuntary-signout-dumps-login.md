# 085 — Desktop involuntary sign-out dumps to login mid-use

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `app/desktop_startup_gate.dart` · `shared/sync/` · gotrue  
**Reported:** 2026-07-19

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I85-T01 | `shouldReturnToAccountOnSignOut` — only `userInitiated` destroys shell while in app | ✅ |
| 2 | I85-T02 | Log auth events + `signOutReason`; keep shell on `sessionExpired` / `sessionMissing` | ✅ |
| 3 | I85-T03 | Clear account features + cancel sync pushes without tearing down navigation | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I85-A01 | Mid-playback involuntary `signedOut` keeps player/shell — no Account entry screen | ⬜ |
| 2 | I85-A02 | Explicit Sign out from Settings / Who’s watching still returns to Account entry | ⬜ |

---

## Summary

`DesktopStartupGate` treated every `AuthChangeEvent.signedOut` as a hard boot to `AccountEntryScreen`. gotrue emits that event when a refresh token is rejected (`SignOutReason.sessionExpired`) — e.g. refresh rotation while the web portal is also signed in, or a non-retryable auth API error. That wiped the running app (player → login) even though the user never signed out.

**Symptom fix:** keep the app shell on involuntary loss; re-auth from Settings. Explicit `userInitiated` sign-out still returns to Account entry.

**Root (tokens):** gotrue still clears the local session when refresh fails — cloud sync stays off until sign-in. Logs now print `event` + `signOutReason` so the next occurrence is diagnosable. Concurrent web + desktop sessions with refresh-token rotation remain a likely server-side cause.
