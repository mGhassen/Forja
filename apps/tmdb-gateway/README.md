# TMDB gateway

Forja-owned TMDB **API + image** reverse proxy. Home pack points `config.base` / `imageBase` here. Credentials stay on the server.

**Cache (Supabase):**
- `/3/*` JSON → Postgres `tmdb_response_cache`
- `/t/p/*` images → Storage bucket `tmdb-images` + `tmdb_image_cache` metadata

## Routes 

| Path | Upstream |
|------|----------|
| `GET /health` | Credential + cache status |
| `GET /3/*` | `https://api.themoviedb.org/3/*` (keyless; server injects key) |
| `GET /t/p/*` | `https://image.tmdb.org/t/p/*` |

`/3/configuration*` rewrites `images.secure_base_url` / `base_url` to this gateway’s `/t/p/`.

## Local

From repo root `.env` (same TMDB + Supabase secrets):

```bash
cd apps/tmdb-gateway
# optional apps/tmdb-gateway/.env.local for TMDB_GATEWAY_PUBLIC_URL / SUPABASE_SERVICE_ROLE_KEY
npm run dev
```

Smoke:

```bash
curl -s http://localhost:3000/health
curl -s http://localhost:3000/3/movie/550 | head -c 200
curl -sI http://localhost:3000/t/p/w500/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg
```

Home local pack config:

```json
"base": "http://localhost:3000/3",
"imageBase": "http://localhost:3000/t/p",
"apiKey": ""
```

## Env

| Variable | Required | Notes |
|----------|----------|--------|
| `TMDB_API_KEYS` | preferred | Comma-separated v3 keys — gateway round-robins across them |
| `TMDB_API_KEY` | fallback | Single key if `TMDB_API_KEYS` unset |
| `TMDB_READ_ACCESS_TOKEN` | optional | Bearer (alias `TMDB_BEARER_TOKEN`) |
| `SUPABASE_URL` | for cache | Same project as apps/web |
| `SUPABASE_SERVICE_ROLE_KEY` | for cache | **Service role** — never ship to clients |
| `TMDB_GATEWAY_PUBLIC_URL` | for config rewrite | e.g. `https://tmdb.forjahq.xyz` |
| `PORT` | no | Local listen (default `3000`) |

Apply migrations before relying on cache (ops approval):

- `*_tmdb_response_cache.sql` — JSON table
- `*_tmdb_image_storage_cache.sql` — image metadata + `tmdb-images` bucket

## Vercel

1. Import this directory as a Vercel project (root: `apps/tmdb-gateway`)
2. Set env vars above + custom domain `tmdb.forjahq.xyz`
3. Framework preset: **Other**. Deployment Protection: **off** for Production.
4. Deploy — routes go through `api/index.js` via `vercel.json` rewrites (`/3/*`, `/t/p/*`, `/health`)

## Cache TTLs

| Class | TTL |
|-------|-----|
| Hot rails (trending / popular / discover) | 20m |
| Other `/3/*` | 8m |
| `/3/configuration*` | 1h |
| `/t/p/*` | 7d (Storage) |
| Errors | not stored |
