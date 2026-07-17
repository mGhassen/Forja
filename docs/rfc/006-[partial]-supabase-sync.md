# RFC-006: Supabase settings sync

**Version:** v1.2  
**Status:** partial  
**Area:** `apps/forja/lib/shared/sync/src/sync_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 3** components · **3 / 4** acceptance (v1.2 slice) · **4 / 5** acceptance (web portal slice) · **8 / 8** acceptance (profiles slice) · **7 / 8** acceptance (desktop account slice) |
| **Current slice** | Desktop account/profile UX shipped locally — hosted GitHub Supabase secrets, per-key timestamp merge, and domain allowlist remain |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-C01 | SyncService (`sync_service.dart`) | ✅ |
| 2 | R06-C02 | Account profiles with profile-scoped settings | ✅ |
| 3 | R06-C03 | Optional desktop account entry and profile-aware shell | 🔄 |

---

## Acceptance (v1.2 slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A01 | Email/password sign-in from Settings → Account | ✅ |
| 2 | R06-A02 | Push/pull settings blobs when signed in | ✅ |
| 3 | R06-A03 | Merge by latest `updated_at` per domain | ⬜ |
| 4 | R06-A04 | Sign-out clears remote session; local data retained | ✅ |

---

## Acceptance (web portal slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A05 | `supabase_flutter` client init from dart-defines | ✅ |
| 2 | R06-A06 | Real Auth signIn / signOut against shared Supabase project | ✅ |
| 3 | R06-A07 | `pushSettings` / `pullSettings` against `user_settings` | ✅ |
| 4 | R06-A08 | Same schema/RLS as `apps/web` account portal | ✅ |
| 5 | R06-A09 | Concrete sync domain allowlist | ⏭️ |

---

## Acceptance (profiles slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A10 | Each account can create, rename, select, and delete multiple profiles | ✅ |
| 2 | R06-A11 | Every settings domain belongs to exactly one profile | ✅ |
| 3 | R06-A12 | Existing account settings migrate into a default profile without data loss | ✅ |
| 4 | R06-A13 | Profile selection is local to each web/app device | ✅ |
| 5 | R06-A14 | Flutter sync reads and writes only the selected profile | ✅ |
| 6 | R06-A15 | RLS prevents access to profiles and profile settings owned by another account | ✅ |
| 7 | R06-A16 | Netflix-style profile chooser with account-owned avatar selection | ✅ |
| 8 | R06-A17 | Avatar picker offers 30 choices grouped into categories of up to eight | ✅ |

---

## Acceptance (desktop account slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-A18 | Unauthenticated desktop launches show account entry before the splash | ✅ |
| 2 | R06-A19 | Continue without an account preserves the existing local-only app flow | ✅ |
| 3 | R06-A20 | A restored authenticated session bypasses account entry and opens the splash directly | ✅ |
| 4 | R06-A21 | Interactive sign-in or account creation opens the account profile chooser before the splash | ✅ |
| 5 | R06-A22 | Choosing a profile activates and pulls that profile before app startup | ✅ |
| 6 | R06-A23 | The desktop rail replaces the Settings glyph with the active profile avatar while still opening Settings | ✅ |
| 7 | R06-A24 | Settings exposes a dedicated Profile & account page for switching profiles and managing the Forja session | ✅ |
| 8 | R06-A25 | Local and CI builds inject the shared Supabase URL and public client key without committing a service-role secret | 🔄 |

---

## Summary

Optional account to backup and restore settings across devices. Offline-first — no auth required to use Forja.


## Stub

`apps/forja/lib/shared/sync/src/sync_service.dart`

## Auth

- Supabase Auth: email/password or magic link
- Sign-in from Settings → Account (new section)
- Sign-out clears remote session only; local data retained

## Schema

```sql
create table profiles (
  id uuid primary key,
  user_id uuid references auth.users not null,
  name text not null
);

create table user_settings (
  user_id uuid references auth.users not null,
  profile_id uuid references profiles not null,
  domain text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (profile_id, domain)
);

alter table user_settings enable row level security;
create policy "own rows" on user_settings
  for all using (auth.uid() = user_id);
```

## Sync domains

| Domain | Payload | Encryption |
|--------|---------|------------|
| iptv | portals, groups, M3U refs | client-side (credentials) |
| stremio | addon URLs | plain |
| providers | order, enabled, lastUsed | plain |
| watch_history | continue watching | plain |
| preferences | theme, subtitles, player | plain |

**Local-only (never sync):** torrent cache, temp files, LAN pairing tokens.

## Merge strategy

On login: pull remote → merge with local per domain; conflict = latest `updated_at` wins per key.

On change: debounced push (5s) when signed in.

Profile selection is stored locally on each device. Switching a profile on one
device does not switch other signed-in devices.

## Client API (to implement)

```dart
class SyncService {
  Future<void> signIn({ email, password });
  Future<void> signOut();
  Future<void> pullAll();
  Future<void> pushDomain(String domain, Map<String, dynamic> payload);
  Stream<SyncStatus> get status;
}
```

## Migrations

Use `supabase migration new <name>` — never create SQL files manually.

