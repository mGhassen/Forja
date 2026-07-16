# RFC-006: Supabase settings sync

**Version:** v1.2  
**Status:** partial  
**Area:** `apps/forja/lib/shared/sync/src/sync_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 1** components · **3 / 4** acceptance (v1.2 slice) · **4 / 5** acceptance (web portal slice) |
| **Current slice** | Web portal — SyncService wired; domain allowlist deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R06-C01 | SyncService (`sync_service.dart`) | ✅ |

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
create table user_settings (
  user_id uuid references auth.users not null,
  domain text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, domain)
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

