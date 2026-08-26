# Forja Admin — IPTV catalog ops (RFC-040)

Second TanStack Start app. Same auth + Forja design tokens/UI primitives as web — **ops pages only** (no portal/marketing/account screens).

## Setup

```bash
cp .env.example .env
# same VITE_SUPABASE_* + Turnstile as apps/web (or use repo-root .env bridge)
pnpm install
pnpm dev   # http://127.0.0.1:4000
```

Sign in with an account where `accounts.is_admin = true`.

**PostHog on Accounts (optional):** set `POSTHOG_PERSONAL_API_KEY` + `POSTHOG_PROJECT_ID` (personal key with `person:read` / query; `POSTHOG_PROJECT_ID` may be numeric or project `phc_…` — resolved via project-scoped `?token=`). See `.env.example`.

## Inngest catalog scrape

```bash
# terminal 1
cd apps/admin && pnpm dev

# terminal 2
npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest
```

Needs `SUPABASE_SERVICE_ROLE_KEY` + Inngest keys (see `.env.example`). Inngest ticks every minute; schedule is `iptv_ops_settings.scrape_cron` (edit in Scrape → Automation). Manual: event `iptv/catalog.scrape`.

**LLM hybrid extract (opt-in, off by default):** only when `IPTV_LLM_EXTRACT=1` **and** `ANTHROPIC_API_KEY`. Mechanical extract always runs first; agent only if mechanical returns **0**. Agent failures are logged and ignored (scrape continues). Default prod path = mechanical only.

**Production (Vercel):** set `INNGEST_SERVE_ORIGIN=https://admin.forjahq.xyz` so Inngest syncs the custom domain. `*.vercel.app` is Deployment-Protected and returns 401 to Inngest. Or sync manually in Inngest → Apps → `https://admin.forjahq.xyz/api/inngest`.

## Routes

| Path | Page |
|------|------|
| `/login` | Same auth + captcha as web |
| `/` | Dashboard |
| `/accounts` | Credits, feature flags, PostHog client runtime (app / platform / last seen) |
| `/pool` | Catalog candidates |
| `/scrape` | Scrape run history |
| `/api/inngest` | Inngest serve (server) |
| `/providers` | Provider runtime JSON (RFC-039) |

## Worker

```bash
cd crates
export SUPABASE_URL=…
export SUPABASE_SERVICE_ROLE_KEY=…
cargo run -p iptv-worker -- scrape --max-pages 10 --verify
```
