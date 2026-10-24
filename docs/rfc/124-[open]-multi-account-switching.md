# RFC-124: Several Forja accounts on one device — switch without signing out

**Status:** open  
**Depends on:** [RFC-082](082-[open]-account-profile-local-data-scope.md) (identity-scoped local data), [RFC-046](046-[open]-android-tv-device-link.md) (TV code sign-in), [RFC-006](006-[partial]-supabase-sync.md) (sessions, desktop browser auth)  
**Area:** `apps/forja/lib/shared/sync/auth/`, `apps/forja/lib/features/account/`, Settings → Profile & account, `apps/web` login page  
**Issues:** [467](../issues/467-[open]-cross-account-simkl-connected-secrets-isolation.md) (no wipe on switch) · [085](../issues/085-[open]-desktop-involuntary-signout-dumps-login.md) (sign-out gate) · [478](../issues/478-[open]-desktop-web-login-auto-handoff-signed-in-portal-user.md) (portal auto-handoff)

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 10** components · **0 / 8** acceptance |
| **Current slice** | Vault + switcher + chooser row + Settings group + add mode + portal account choice |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R124-C01 | `AccountVault` — one secure key `forja_account_vault_v1` with per-user refresh token, email, aal, last used, `needsSignIn`; cap 5; listener on the auth stream keeps the active account's rotated token fresh | ✅ |
| 2 | R124-C02 | `SessionGateway` seam over GoTrue: main client + throwaway probe client (no auto-refresh, no storage) so a revoked token never emits `signedOut` on the main stream | ✅ |
| 3 | R124-C03 | `AccountSwitcher.switchTo`: push pending → stop auto-refresh → await in-flight refresh → snapshot leaving account → probe target → persist → `setSession(rt, accessToken)` → restart refresh → MFA check → last profile; typed results (switched / alreadyActive / pushFailed / offline / needsSignIn / mfaRequired / failed) | ✅ |
| 4 | R124-C04 | Vault listener bound in bootstrap before the forced session refresh | ✅ |
| 5 | R124-C05 | Who's watching: account row above the title — active chip, "Sign in again" chips, **Add account**; Manage mode → **Remove from this device**; D-pad focus highlights only, OK switches; autofocus stays on the active profile | ✅ |
| 6 | R124-C06 | Settings → Profile & account → **Accounts on this device** group: Switch / Remove per account, Add account | ✅ |
| 7 | R124-C07 | Add mode on the desktop account entry, TV link screen and Settings sign-in: leaving account snapshotted first; same user again → "Already on this device" | ✅ |
| 8 | R124-C08 | `MfaChallengeView` extracted and reused after a switch to an aal1 session of an MFA-enrolled account; cancel returns to the previous account | ✅ |
| 9 | R124-C09 | Web login with `desktop_switch=1`: portal asks **Continue as <email> / Use another account** instead of auto-handing-off the signed-in browser user ([478](../issues/478-[open]-desktop-web-login-auto-handoff-signed-in-portal-user.md)) | ✅ |
| 10 | R124-C10 | Keep inactive vault entries alive (probe refresh at most weekly at cold start) so the 30-day inactivity timeout does not force "Sign in again" | ⏭️ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R124-A01 | Desktop + TV: switch A → B → A; A's IPTV portals, My List, continue watching and Simkl link are back without re-linking; B never sees them | ⬜ |
| 2 | R124-A02 | Log shows `signedIn` only during a switch — never `signedOut`; the sign-out gate does not wipe anything | ⬜ |
| 3 | R124-A03 | Revoke B's session from the portal → switch to B shows "Sign in again"; A stays active | ⬜ |
| 4 | R124-A04 | Offline → switch shows the connection message; A intact | ⬜ |
| 5 | R124-A05 | Remove inactive B revokes only B's session (portal Connections); B's local data stays on the device | ⬜ |
| 6 | R124-A06 | MFA-enrolled account: switching prompts TOTP; cancel returns to the previous account | ⬜ |
| 7 | R124-A07 | Android TV: chips highlight on D-pad without switching; OK switches; autofocus lands on the active profile tile; no text field appears | ⬜ |
| 8 | R124-A08 | Web login started from Forja in add mode shows the portal account choice; the chosen account lands in the app | ⬜ |

---

## Summary

Forja keeps exactly one GoTrue session on a device and the only way to change account is sign-out, which revokes the session and wipes account-bound local state. Local data is already isolated per account and profile (RFC-082), and issue 467 made tracker links and pack secrets follow that scope, so the data side of switching is solved. What is missing is holding several sessions.

### Design

- **One live session, one vault.** The existing persisted slot stays the active account. A device-global secure vault holds the other accounts' refresh tokens. Never synced, never exported (RFC-123 A03).
- **Switch = `setSession`, never sign-out.** `/logout` revokes the current session server-side and the gate wipes local state on `signedOut`. The switcher probes the target token on a throwaway client first, persists the fresh token, then applies it to the main client with the access token so GoTrue takes the `getUser` path and emits `signedIn` only.
- **Token rotation safety.** GoTrue rotates refresh tokens; reusing a stale one outside the reuse interval revokes the whole family. The switcher stops auto-refresh, awaits any in-flight refresh, then snapshots. Every `tokenRefreshed` event also updates the vault.
- **Failures are messages, not wipes.** Revoked token → chip flagged "Sign in again", current account untouched. Offline → message. Push failure → nothing changes.
- **Removal keeps data.** Removing an inactive account revokes its session and drops the vault entry; its local scope stays on disk (467 policy). Deleting that scope is a later, explicit option.

### Known limits (this slice)

- A refresh that starts after the switch snapshot and finishes after the apply is discarded by GoTrue's version guard, so the leaving account's stored token is the pre-rotation one; outside Supabase's reuse window that account later shows "Sign in again". A switch-in-progress latch on `refreshSession` closes it (follow-up row).
- With five accounts saved, a sixth sign-in from the sign-in gate evicts the least recently used entry without a message; the active account is never evicted.
- Error text in the new account screens uses the host's existing red literal; no semantic error token exists in the shell palette yet.

### Out of scope

- Per-device session labels in the portal (adding an account on a second desktop still revokes the other desktop's session of the same account, existing `mint-desktop-session` behaviour).
- Offline switching: `setSession` needs the network.

### Related

- [Account switching](../features/accounts/account-switching.md) — user guide
- [Cloud sync](../features/settings/cloud-sync.md)
- [RFC-123](123-[draft]-device-data-transfer-lan-realtime.md) — a transfer always lands in the receiver's current account
