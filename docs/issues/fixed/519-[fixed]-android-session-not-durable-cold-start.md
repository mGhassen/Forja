# 519 — Android session not durable across cold start

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** `ForjaPlatformSecureStore` · Supabase auth · Android phone / TV  
**Reported:** 2026-10-29 (mobile emulator: every open → sign-in; packs wipe)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred

---

## Symptom

On Android (phone flavor emulator), cold start shows **Sign in** even after a successful login. Boot log: `persistedSession=false` / `signedIn=false`. Guest scope then runs `PluginNav refresh empty-install wipe` and the navbar looks wiped.

## Root cause

`ForjaPlatformSecureStore` dual-wrote EncryptedSharedPreferences + a SharedPreferences vault. On this device both were empty for `sb-*-auth-token` after restart (EncryptedSharedPreferences already known flaky on emulator; prefs vault string also missing). GoTrue `LocalStorage` + account session vault both read through that store → no session → account gate.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I519-T01 | Android: flush session secrets to Application Support file vault (`forja_secure_vault_v1`) on write; read prefs → file → encrypted | ✅ |
| 2 | I519-T02 | `ForjaSecureLocalStorage.persistSession` round-trip check + retry; password sign-in durability log | ✅ |
| 3 | I519-T03 | Unit: file vault recovers after prefs cleared | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I519-A01 | Android phone: sign in → kill app → reopen stays signed in (no account gate) | ⬜ |
| 2 | I519-A02 | After restore, Features / packs for that profile load (no empty-install wipe of a real install) | ⬜ |

## Related

- [109](../109-[open]-android-tv-boot-jwt-expired-discard-race.md) — JWT refresh race (session present)
- [085](../085-[open]-desktop-involuntary-signout-dumps-login.md) — hard signedOut
- [274](274-[fixed]-debug-release-shared-session.md) — debug/release shared namespace
