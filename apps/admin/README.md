# Forja Admin — IPTV catalog ops (RFC-040)

Thin ops console for the shared Forja Supabase project. Not a clone of the user portal.

## Setup

```bash
cp .env.example .env
# same VITE_SUPABASE_* as apps/web
npm install
npm run dev   # http://localhost:5174
```

Sign in with an account where `accounts.is_admin = true`.

## Apply schema

From `apps/web` (after linking / local supabase):

```bash
# local
supabase db reset   # only if you intend to wipe local — ask before prod
# or push the new migration only on a linked project (ops)
```

Migration: `supabase/migrations/20260718224617_iptv_catalog_ops.sql`

## Worker

```bash
cd crates
export SUPABASE_URL=…
export SUPABASE_SERVICE_ROLE_KEY=…
cargo run -p iptv-worker -- scrape --dry-run --max-pages 2
cargo run -p iptv-worker -- scrape --max-pages 10 --verify
```
