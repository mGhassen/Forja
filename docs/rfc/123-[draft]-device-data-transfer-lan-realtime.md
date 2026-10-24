# RFC-123: Move my local data to another device (LAN pull · account relay, nothing stored)

**Status:** draft  
**Depends on:** [RFC-082](082-[open]-account-profile-local-data-scope.md) (identity-scoped stores, A10 backup export), [RFC-022](022-[open]-lan-server-client.md) (LAN server, pairing, mDNS), [RFC-006](006-[partial]-supabase-sync.md) (Supabase client, sessions)  
**Area:** `packages/rust` (bundle build / merge), `crates/lan` (bundle route), `apps/forja/lib/shared/{lan,sync}`, Settings → Data & backup  
**Issues:** [467](../issues/467-[open]-cross-account-simkl-connected-secrets-isolation.md) (no secrets leave the identity)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 7** components · **0 / 8** acceptance |
| **Current slice** | Not scheduled |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R123-C01 | `LocalDataBundle` (bridge): export of the **active identity only** — My List, watch history + resume, dismissed, watched episodes + timestamps, pack continue-watching, pack settings, synced settings KV. No secrets, no IPTV catalog, no images, no pack JS | ⬜ |
| 2 | R123-C02 | `LocalDataBundle.merge` (bridge): union lists; highest progress per item; newest timestamp wins for status / watched marks; never touches secure keys; writes only under the receiving device's active scope | ⬜ |
| 3 | R123-C03 | LAN pull: bearer `GET /bundle` on the `crates/lan` server returns the sender's active-identity bundle; TV (paired client) pulls it over the existing mDNS-discovered connection | ⬜ |
| 4 | R123-C04 | Account relay: Supabase Realtime **Broadcast** on a private per-user channel (`transfer:<userId>`, RLS on `realtime.messages`); receiver shows a 6-digit code, sender derives a key from it, bundle sent encrypted in chunks; nothing persisted in Postgres | ⬜ |
| 5 | R123-C05 | Settings → Data & backup: **Send to another device** (sender) and **Receive from another device** (receiver) entries; receiver lists LAN devices first, falls back to the account relay; progress + merge summary | ⬜ |
| 6 | R123-C06 | Android TV: receiver screen is D-pad first (code display, device list, one Accept button); any text field browse-until-activate | ⬜ |
| 7 | R123-C07 | Bundle size guard and chunking (LAN streams the body; relay chunks under the Realtime per-message limit with ack per chunk) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R123-A01 | Desktop A (account X / profile p1) → TV B (account X / profile p1) over LAN: My List, continue watching, resume positions and watched marks appear on B; B's existing rows survive the merge | ⬜ |
| 2 | R123-A02 | Same transfer over the account relay with both devices on different networks; Supabase tables show zero new rows | ⬜ |
| 3 | R123-A03 | Bundle contains no Simkl / MDBList / debrid / pack secret, no IPTV password, no `sb-*` token (unit test on the serialized bundle) | ⬜ |
| 4 | R123-A04 | Receiver signed in as another account, or as guest, receives into **its own** scope only; sender identity never bleeds (RFC-082 rule) | ⬜ |
| 5 | R123-A05 | Wrong code on the relay → receiver cannot decrypt; sender sees "code did not match"; nothing applied | ⬜ |
| 6 | R123-A06 | Transfer interrupted mid-way → receiver applies nothing (merge is all-or-nothing after the last chunk) | ⬜ |
| 7 | R123-A07 | Leanback: whole receive flow completes with D-pad only; code is readable at 10 ft | ⬜ |
| 8 | R123-A08 | Settings "clear" entries on the receiver still clear only the active identity after a merge | ⬜ |

---

## Summary

Nothing moves lists or history between devices today. The LAN engine carries stream open / close only (`crates/lan/src/server.rs` routes), Backup & restore exports settings and keys only (`SettingsService.exportAllSettings`), and cloud sync pushes one lean `profile_settings` payload without lists or history. A user with a desktop full of history and a fresh TV has to rebuild everything.

Target: one **bundle** of the active identity's user-managed local data and two **transports** that both leave the database untouched.

### Bundle

Built and merged in `packages/rust` next to the stores it reads (`BookmarkStore`, `WatchHistoryService`, `EpisodeWatchedService`, pack CW prefs, `PackSettingsStore`, settings KV). JSON envelope: `{ v, createdAt, sourceDevice, scope: { accountId, profileId }, stores: {...} }`. The receiver ignores `scope` for placement and always writes under its own active identity; `scope` is shown to the user only.

Not in the bundle: anything in the secure store, IPTV catalog SQLite / shelf snapshots (rebuilt from the portal), image / WebView caches, pack JS bodies (reinstalled from the catalog), stream extract cache.

### Transport 1 — LAN pull

Desktop already runs the paired LAN server (RFC-022: one-time code pairing, bearer tokens, mDNS `_forja._tcp`). Add a protected `GET /bundle`. The TV, already a paired client, lists discovered servers and pulls. No internet, no account needed. Direction is receiver-pulls; "Send to another device" on the desktop just turns the server on and shows the pairing code if the TV is not yet paired.

### Transport 2 — account relay (no persistence)

Supabase Realtime Broadcast relays messages between subscribers of a channel without writing rows (Broadcast is distinct from Postgres Changes and from broadcast-from-database triggers, which this RFC does not use). Channel `transfer:<userId>` is private (`realtime.messages` RLS: `auth.uid() = split_part(topic, ':', 2)`), so only the same account's devices can join. The receiver shows a 6-digit code; the sender derives an AES-GCM key from code + a random salt sent in the first message (PBKDF2 / HKDF); payload chunks are ciphertext, so the relay sees nothing readable. Chunks are acked by the receiver; the last chunk carries a hash of the whole bundle; merge runs only when the hash matches.

Needs one SQL migration for the RLS policy on `realtime.messages` (web repo, additive, no table). No edge function.

### Merge rules

| Store | Rule |
|---|---|
| My List statuses | union by identity; newest `updatedAt` wins per title |
| Watch history / resume | highest position per item; keep both devices' items |
| Watched episodes | union; newest timestamp wins |
| Pack continue-watching | union per plugin |
| Pack settings / settings KV | receiver keeps its own unless empty (opt-in "replace settings" checkbox) |
| Secrets | never read, never written |

### Related

- [Backup & restore](../features/settings/backup-restore.md) — stays the file-based settings snapshot
- [Cloud sync](../features/settings/cloud-sync.md)
- [RFC-124](124-[open]-multi-account-switching.md) — account switching; a transfer always lands in the receiver's **current** account
