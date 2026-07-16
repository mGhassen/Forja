# Forja web (`apps/web`)

Creative-agency landing, account portal, and Supabase-backed APIs shared with the Flutter app.

## Stack

- TanStack Start (React + file routes + SSR)
- TanStack Query
- Tailwind CSS + shadcn-style UI primitives
- Supabase Auth / Postgres / Storage / Edge Functions

## Setup

```bash
cd apps/web
pnpm install
cp .env.example .env
# fill VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
pnpm dev
```

## Deploy (Vercel)

1. Root Directory: `apps/web`
2. Framework Preset: TanStack Start
3. Leave Build / Output / Install on defaults (do **not** override Output to `dist`)
4. Env: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`

Nitro (`nitro()` in `vite.config.ts`) is required — without it Vercel returns `404: NOT_FOUND` because there is no serverless entry.

## Scripts

| Command | Purpose |
|---------|---------|
| `pnpm dev` | TanStack Start / Vite dev server (`:3000`) |
| `pnpm build` | Production client + SSR build |
| `pnpm preview` | Preview production build |
| `pnpm supabase:reset` | Local DB reset + test users (`forja-dev`, ports 55321+) |

## Supabase

Migrations and the `sync-github-releases` Edge Function live under [`supabase/`](./supabase/). Local ports and reset flow: [`supabase/README.md`](./supabase/README.md).

**Local (Docker):** from repo root, `node scripts/reset-forja-supabase.js` — then paste the printed keys into `.env`.

**Remote:**

1. Create a Supabase project (or link an existing one)
2. Apply migrations: `supabase db push` (from `apps/web` with CLI linked)
3. Deploy the Edge Function and set secrets (`GITHUB_TOKEN` optional for higher rate limits)
4. Invoke `sync-github-releases` after each GitHub release (or schedule a cron)

Same project URL/anon key are used by Flutter via `--dart-define=SUPABASE_URL` / `SUPABASE_ANON_KEY`.

## Routes

| Path | Access |
|------|--------|
| `/` | Public landing |
| `/iptv` | IPTV player story — free, no ads |
| `/download` | Public — latest mirrored release |
| `/login`, `/signup` | Auth |
| `/account` | Authenticated |
| `/account/settings` | Authenticated — sync domain status |

File routes live under `src/routes/`. Page UI stays in `src/pages/`.
