# Forja web — Supabase

Local stack uses **project_id `forja-dev`** and ports **55321–55326** (Dose / other projects keep 64321+ and default 54321+ free).

| Service | Port |
|---------|------|
| API (Kong) | 55321 |
| Postgres | 55322 |
| Studio | 55323 |
| Inbucket UI | 55324 |
| Inbucket SMTP | 55325 |
| Inbucket POP3 | 55326 |

## Local reset + test users

From the repo root (Docker + [Supabase CLI](https://supabase.com/docs/guides/cli) required):

```bash
node scripts/reset-forja-supabase.js
```

That will:

1. Start or resume `forja-dev` containers if needed
2. `supabase db reset` (migrations + `seed.sql`)
3. Create test users via Auth Admin API

**Test logins**

| Email | Password |
|-------|----------|
| `user@forja.local` | `password123` |
| `demo@forja.local` | `password123` |

Then put the printed `VITE_SUPABASE_*` values into `apps/web/.env` (or run `supabase status` from `apps/web`).

From `apps/web` only:

```bash
supabase start
supabase db reset
node ../../scripts/create-forja-test-users.js
```

## Remote (production / shared project)

```bash
cd apps/web
supabase link --project-ref <ref>
supabase db push
supabase functions deploy sync-github-releases
```

Secrets for the Edge Function (optional):

```bash
supabase secrets set GITHUB_TOKEN=ghp_...
# GITHUB_REPO defaults to mGhassen/Forja
```

Invoke after a release:

```bash
supabase functions invoke sync-github-releases --no-verify-jwt
```

Or schedule via Supabase Dashboard → Edge Functions → Cron.
