# 323 — Supabase AuthRetryableFetchException on cold-start DNS blip

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** `shared/sync/` · `app/bootstrap.dart` · `app/desktop_startup_gate.dart` · gotrue  
**Reported:** 2026-09-23

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I323-T01 | Classify `AuthRetryableFetchException` / DNS as soft network; keep cached session | ✅ |
| 2 | I323-T02 | Gate: debounced refresh after bootstrap force (no second forced `/token`); deferred soft retry | ✅ |
| 3 | I323-T03 | Quiet `[YT ERROR]` stack dumps for retryable auth network blips | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I323-A01 | Cold start with brief DNS failure: splash stays signed-in; no scary auth stack storm; session refreshes after network returns | ⬜ |

---

## Summary

Cold start forced `refreshSession` in **bootstrap** and again in **DesktopStartupGate**. A transient `Failed host lookup` on `*.supabase.co` made gotrue retry `/token`, emit `AuthRetryableFetchException` on `onAuthStateChange`, and dump a full `[YT ERROR]` stack — even though the local session stayed valid and a later refresh succeeded.

**Root (noise / double hit):** Second forced refresh raced a DNS blip; gotrue treats that as retryable and notifies the auth stream. Forja already returned `false` from `refreshSession` on timeout/`AuthException` and kept `signedIn`.

**Fix:** Classify retryable auth network errors; soft-log stream errors; skip redundant force refresh in the gate (debounce after bootstrap); suppress YT stack dumps for those blips; one deferred soft retry.

**Related:** [109](../109-[open]-android-tv-boot-jwt-expired-discard-race.md) (boot force refresh) · [106](../106-[open]-desktop-session-profile-chrome-desync.md) (hung DNS + Sign out)
