# TMDB gateway

Forja-owned TMDB **API + image** reverse proxy. Home pack points `config.base` / `imageBase` here. Credentials stay on the server.

**Primary host:** Cloudflare Workers (`tmdb.forjahq.xyz`) — avoids Vercel Fast Data Transfer on `/3/*` JSON.  
**Local:** Node (`npm run dev`).  
**Rollback:** Vercel entry under `api/` still works if DNS is pointed back.

**Cache:**
- `/3/*` JSON → Postgres `tmdb_response_cache`
- `/t/p/*` images → R2 `forja-tmdb` + Postgres `tmdb_image_cache` — gateway returns **302** to R2 (`R2_TMDB_PUBLIC_BASE` preferred; Node may presign)
- Daily purge (`0 4 * * *` Workers cron, or Vercel cron) → `/internal/purge-expired`

Issue: [519](../../docs/issues/519-[open]-tmdb-gateway-cloudflare-workers.md)

## Routes

| Path | Upstream |
|------|----------|
| `GET /health` | Credential + cache + `runtime` |
| `GET /3/*` | `https://api.themoviedb.org/3/*` (keyless; server injects key) |
| `GET /t/p/*` | Cache miss: TMDB → R2, then **302** to R2; hit: **302** to R2 |
| `GET /internal/purge-expired` | TTL purge (Bearer secret; Workers cron daily 04:00 UTC) |

`/3/configuration*` rewrites `images.secure_base_url` / `base_url` to this gateway’s `/t/p/`.

## Local (Node)

```bash
cd apps/tmdb-gateway
npm install
npm run dev
```

Smoke:

```bash
curl -s http://localhost:3000/health
curl -s http://localhost:3000/3/movie/550 | head -c 200
curl -sI http://localhost:3000/t/p/w500/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg
```

## Cloudflare Workers (production)

1. `npm install` in `apps/tmdb-gateway`
2. `npx wrangler login` (or `CLOUDFLARE_API_TOKEN`)
3. Enable **public read** on R2 bucket `forja-tmdb` (or attach a custom public domain) and note the base URL
4. Put secrets (see list below) + set `R2_TMDB_PUBLIC_BASE` to that public origin
5. `npm run cf:deploy`
6. Workers → **Domains** → add `tmdb.forjahq.xyz` (DNS at Cloudflare or CNAME to `*.workers.dev` target Wrangler prints)
7. Remove / disable the Vercel custom domain for the same host so traffic is not split
8. Smoke:

```bash
curl -s https://tmdb.forjahq.xyz/health
# expect "runtime":"cloudflare-workers", "r2Binding":true, "r2PublicBase":true
curl -sI https://tmdb.forjahq.xyz/t/p/w500/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg
# expect 302, X-TMDB-Image-Mode: redirect, Location on R2 public base
```

Local Worker preview: copy `.dev.vars.example` → `.dev.vars`, then `npm run cf:dev`.

### Secrets (`wrangler secret put …`)

| Secret | Required |
|--------|----------|
| `TMDB_API_KEYS` or `TMDB_API_KEY` | yes |
| `TMDB_READ_ACCESS_TOKEN` | optional |
| `SUPABASE_URL` | for cache |
| `SUPABASE_SERVICE_ROLE_KEY` | for cache |
| `TMDB_CACHE_PURGE_SECRET` | for purge / cron |
| `R2_TMDB_PUBLIC_BASE` | **yes on Workers** (stable 302; no AWS sign CPU) |

`wrangler.toml` already binds `TMDB_R2` → bucket `forja-tmdb`. S3 access keys are **not** required on Workers when the binding + public base are set.

## Env (Node / Vercel rollback)

| Variable | Required | Notes |
|----------|----------|--------|
| `TMDB_API_KEYS` | preferred | Comma-separated v3 keys |
| `TMDB_API_KEY` | fallback | Single key |
| `TMDB_READ_ACCESS_TOKEN` | optional | Bearer |
| `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` | for cache | Service role — never ship to clients |
| `R2_*` | Node images | Account + keys + `R2_TMDB_BUCKET=forja-tmdb` |
| `R2_TMDB_PUBLIC_BASE` | recommended | Public CDN origin for objects |
| `TMDB_CACHE_PURGE_SECRET` | for purge | Or `CRON_SECRET` |
| `TMDB_GATEWAY_PUBLIC_URL` | for config rewrite | `https://tmdb.forjahq.xyz` |

## Cache TTLs

| Class | TTL |
|-------|-----|
| Hot rails (trending / popular / discover) | 20m |
| Other `/3/*` | 8m |
| `/3/configuration*` | 1h |
| `/t/p/*` | 7d (R2) |
| Errors | not stored |
