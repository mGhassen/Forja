# IPTV — Catalog ops (admin)

> Central scrape pool, credits, and admin tools for IPTV portal inventory (operators only).

## What it is

Operators scrape Reddit IPTV posts with a Rust worker, store verified portals in a shared **catalog pool**, grant **credits**, and let users **deal** packs of portals. End users do not use this console — they use the Forja app / Account portal.

## How to open it

1. Apply migrations `20260718224617_iptv_catalog_ops.sql` and `20260718225349_iptv_catalog_region_ops.sql` on the Forja Supabase project
2. Set `accounts.is_admin = true` for your operator account
3. From `apps/admin`: `pnpm install`, `pnpm dev` → **http://127.0.0.1:4000**
4. Sign in with the same Auth + Turnstile stack as the user portal (same Supabase project)

## What you can do

- **Dashboard** — pool size, alive count, scrape runs, account count
- **Accounts** — search by email; toggle `iptvScrape`; grant/revoke credits (+5 / −1)
- **Pool** — table of hosts (one line: host / accounts / alive / scraped); expand to a 2-column portal grid (Account→IPTV row content, actions on hover). Start/stop scrape from the bar
- **Scrape** — view worker run history (pages, L1 extract, upserted, alive)

## Scrape (Inngest on admin)

Production scrape runs in **TypeScript** on `apps/admin` via Inngest (Rust `iptv-worker` is optional/local only).

1. Set on the admin deploy: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `INNGEST_EVENT_KEY`, `INNGEST_SIGNING_KEY`
2. Sync `https://<admin-host>/api/inngest` in the Inngest dashboard
3. Daily cron `0 6 * * *` UTC runs `iptv-catalog-scrape`
4. Each portal is a step `verify-portal-status-*` that hits Xtream `player_api` then upserts into the pool

Local:

```bash
cd apps/admin && pnpm dev   # :4000
npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest
# Invoke iptv-catalog-scrape or send event iptv/catalog.scrape
# Optional data: { "maxPages": 5, "maxVerify": 40 }
```

Optional local Rust (on hold for cron):

```bash
cd crates
export SUPABASE_URL=…
export SUPABASE_SERVICE_ROLE_KEY=…
cargo run -p iptv-worker -- scrape --verify
```

## Deal (API)

Authenticated users with credits call RPC `deal_iptv_portals(profile_id, region, count)` (default region `ANY`, count `5`). Burns **1 credit**, assigns up to N alive pool portals into `user_iptv_portals`.

In the Forja app: IPTV → Portals → **Deal** — pick a region, spend 1 credit for up to 5 portals. Account → IPTV on the web shows the credit balance (deal itself stays in-app).

## Tips

- **Separate app** from the user portal (`apps/web`), but **same** TanStack Start stack, Forja design tokens/UI, AuthProvider, and Turnstile
- Stalker/MAC notes are skipped by extract (Xtream only)
- With `scrape --verify`, region is guessed from timezone + live category names
- Agents must **not** run `supabase db reset` or `db push` unless you explicitly approve in chat

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [RFC-040](../../rfc/040-[open]-iptv-catalog-ops.md)
- [apps/admin README](../../../apps/admin/README.md)
