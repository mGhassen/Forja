# RFC-006: Supabase settings sync

**Version:** v1.2  
**Status:** stub  
**Target version:** v2 (Diwan & mer)  
**Area:** `apps/forja/lib/shared/sync/src/sync_service.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 1** components · **0 / 4** acceptance (v1.2 slice) |
| **Current slice** | v1.2 — optional auth + settings sync |
| **Backlog** | v2 |

## Summary

Optional account to backup and restore settings across devices. Offline-first — no auth required to use Forja.

## Components

| Piece | Path | Status |
|-------|------|--------|
| SyncService | `shared/sync/src/sync_service.dart` | Stub |

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

## Acceptance (v1.2)

- [ ] App works fully without account
- [ ] Login restores settings on fresh install
- [ ] IPTV passwords encrypted before upload
- [ ] RLS enforced; user A cannot read user B
