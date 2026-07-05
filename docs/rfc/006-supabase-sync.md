# RFC-006: Supabase settings sync

## Optional auth

- Supabase Auth (email/password)
- Table `user_settings(user_id, domain, payload jsonb, updated_at)`
- RLS on `auth.uid()`
- Client encrypts IPTV credentials before upload

Stub: `apps/forja/lib/shared/sync/src/sync_service.dart`
