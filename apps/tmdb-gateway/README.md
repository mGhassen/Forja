# TMDB gateway

Forja-owned TMDB **API + image** reverse proxy. Home pack points `config.base` / `imageBase` here. Credentials stay on the server.

**Cache:**
- `/3/*` JSON → Postgres `tmdb_response_cache` (served by Vercel)
- `/t/p/*` images → R2 `forja-tmdb` + Postgres `tmdb_image_cache` — gateway returns **302** to R2 (presigned, or public base if set) so image bytes skip Vercel Fast Origin Transfer
- Daily purge (`/internal/purge-expired`, 04:00 UTC) deletes expired JSON rows and expired image rows **plus** matching R2 objects (Hobby cron limit)

## Routes

| Path | Upstream |
|------|----------|
| `GET /health` | Credential + cache status |
| `GET /3/*` | `https://api.themoviedb.org/3/*` (keyless; server injects key) |
| `GET /t/p/*` | Cache miss: TMDB → R2, then **302** to R2; hit: **302** to R2 |
| `GET /internal/purge-expired` | TTL purge (Bearer secret; Vercel Cron daily 04:00 UTC) |

`/3/configuration*` rewrites `images.secure_base_url` / `base_url` to this gateway’s `/t/p/`.

## Local

From repo root `.env` (TMDB + Supabase + R2):

```bash
cd apps/tmdb-gateway
# optional apps/tmdb-gateway/.env.local for TMDB_GATEWAY_PUBLIC_URL / SUPABASE_SERVICE_ROLE_KEY
npm install
npm run dev
```

Smoke:

```bash
curl -s http://localhost:3000/health
curl -s http://localhost:3000/3/movie/550 | head -c 200
curl -sI http://localhost:3000/t/p/w500/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg
curl -s -H "Authorization: Bearer $TMDB_CACHE_PURGE_SECRET" \
  http://localhost:3000/internal/purge-expired
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
| `R2_ACCOUNT_ID` | for images | Cloudflare account id |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | for images | Must allow bucket `forja-tmdb` |
| `R2_ENDPOINT` | for images | `https://{account}.r2.cloudflarestorage.com` |
| `R2_TMDB_BUCKET` | for images | `forja-tmdb` (do not reuse `R2_BUCKET=forja-releases`) |
| `R2_TMDB_PUBLIC_BASE` | optional | Public CDN origin for objects (e.g. `https://pub-….r2.dev` or custom domain). If unset, redirects use **presigned** URLs (bucket stays private). |
| `TMDB_CACHE_PURGE_SECRET` | for purge | Bearer for `/internal/purge-expired` (or use `CRON_SECRET` on Vercel) |
| `TMDB_GATEWAY_PUBLIC_URL` | for config rewrite | e.g. `https://tmdb.forjahq.xyz` |
| `PORT` | no | Local listen (default `3000`) |

Apply migrations before relying on cache (ops approval):

- `*_tmdb_response_cache.sql` — JSON table
- `*_tmdb_image_storage_cache.sql` — image metadata table (Storage bucket is legacy; blobs are on R2)

## Vercel

1. Import this directory as a Vercel project (root: `apps/tmdb-gateway`)
2. Set env vars above + custom domain `tmdb.forjahq.xyz`
3. Framework preset: **Other**. Deployment Protection: **off** for Production.
4. Cron: Hobby allows **daily** only (`0 4 * * *`). Set `CRON_SECRET` or `TMDB_CACHE_PURGE_SECRET` so `GET /internal/purge-expired` is authorized.
5. Deploy — routes go through `api/index.js` via `vercel.json` rewrites

### Cutover from Supabase Storage

1. Deploy with R2 env set.
2. `TRUNCATE public.tmdb_image_cache;` on hosted Supabase (old meta pointed at Storage).
3. Smoke: `curl -sI https://tmdb.forjahq.xyz/t/p/w500/…` → `302`, `X-TMDB-Image-Mode: redirect`, `Location` on R2; object under `t/p/...` in `forja-tmdb`.
4. Smoke purge: expired row → `GET /internal/purge-expired` with Bearer → row + R2 object gone.

### Cutting Vercel image egress

Redirects are on by default when R2 is configured (presigned). For stable URLs / better client cache: enable public read on `forja-tmdb` (or a custom domain) and set `R2_TMDB_PUBLIC_BASE`.

## Cache TTLs

| Class | TTL |
|-------|-----|
| Hot rails (trending / popular / discover) | 20m |
| Other `/3/*` | 8m |
| `/3/configuration*` | 1h |
| `/t/p/*` | 7d (R2) |
| Errors | not stored |

Expired entries are removed by the daily purge (row + R2 object). Lazy delete on read remains as a safety net.
