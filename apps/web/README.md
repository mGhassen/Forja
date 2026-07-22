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
# fill VITE_SUPABASE_URL, VITE_SUPABASE_PUBLISHABLE_KEY, VITE_TURNSTILE_SITE_KEY
pnpm dev
```

Local Turnstile uses Cloudflare’s always-pass dummy site key (already in `.env.example`);
`supabase/config.toml` enables Auth captcha with the matching dummy secret. Restart
local Supabase after changing captcha settings (`supabase stop && supabase start`).

## Deploy (Vercel)

1. Root Directory: `apps/web`
2. Framework Preset: TanStack Start
3. Leave Build / Output / Install on defaults (do **not** override Output to `dist`)
4. Env: `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_TURNSTILE_SITE_KEY`

Nitro (`nitro()` in `vite.config.ts`) is required — without it Vercel returns `404: NOT_FOUND` because there is no serverless entry.

## Scripts

| Command | Purpose |
|---------|---------|
| `pnpm dev` | TanStack Start / Vite dev server on `http://127.0.0.1:3000` (IPv4 — matches Flutter Web login) |
| `pnpm build` | Production client + SSR build |
| `pnpm preview` | Preview production build |
| `pnpm supabase:reset` | Local DB reset + test users (`forja-dev`, ports 55321+) |

## Supabase

Migrations and the `sync-github-releases` Edge Function live under [`supabase/`](./supabase/). Local ports and reset flow: [`supabase/README.md`](./supabase/README.md).

**Local (Docker):** from repo root, `node scripts/reset-forja-supabase.js` — then paste the printed keys into `.env`.

**Remote:**

1. Create a Supabase project (or link an existing one)
2. Apply migrations: `supabase db push` (from `apps/web` with CLI linked)
3. Set host env `RELEASE_CDN_URL` / `VITE_RELEASE_CDN_URL` to the public R2 CDN base (required for `/download` and `/api/changelog`)

Same project URL/publishable key are used by Flutter via `--dart-define=SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY`.

## Routes

| Path | Access |
|------|--------|
| `/` | Public landing |
| `/iptv` | IPTV player story — live playlists & controls |
| `/download` | Public — per-platform latest installers from R2 `latest/manifest.json` |
| `/changelog` | Public — release notes from R2 `changelog/` |
| `/terms` | Terms of use |
| `/dmca` | DMCA / copyright notice |
| `/login`, `/signup` | Public — email/password auth (Turnstile when configured) |
| `/account` | Authenticated — redirects into settings |
| `/account/profiles` | Authenticated — Who's watching / manage profiles |
| `/account/settings/*` | Authenticated — Profile sync domains + Account (logout / delete) |

File routes live under `src/routes/`. Page UI stays in `src/pages/`.
