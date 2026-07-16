# Cloud sync

> Optional Forja account to back up settings across devices via Supabase.

## What it is

Cloud sync stores settings domain blobs in Supabase under your Forja account. The same account works on the web portal (`apps/web`) and in the desktop/mobile app. The app stays offline-first — you do not need an account to use Forja.

Which domains sync is still being chosen; the plumbing (sign-in, push, pull) is ready.

## How to open it

- **App:** Settings → Accounts → **Forja account**
- **Web:** sign in at `/login`, then **Account → Manage settings sync**

## What you can do

- Create an account or sign in with email and password
- Sign out (local settings stay on the device)
- See how many domains are stored remotely (web portal and app status)
- Push/pull domain payloads when the app enables specific domains later

## Setup

Builds need the shared Supabase project:

```text
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_ANON_KEY=...
```

Web uses `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` in `apps/web/.env`.

## Tips

- Schema and RLS live in `apps/web/supabase/migrations/`
- Domain allowlist is deferred (RFC-006 R06-A09)

## Related

- [Backup & restore](backup-restore.md) — local export/import available today
- [App updates](app-updates.md)
- [Watch history](../movies-tv/watch-history.md)
- [My List](../movies-tv/my-list.md)
