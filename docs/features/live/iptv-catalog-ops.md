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
- **Pool** — table of hosts (one line: host / accounts / alive / scraped); expand to a 2-column portal grid (Account→IPTV row content, actions on hover). Filter by **status** (alive / dead / unchecked) and **region**. **Check status** (radio icon) on a portal or on the host row runs Xtream `player_api` and updates alive/expiry/region. Start/stop scrape from the bar
- **Scrape** — view worker run history (pages, L1 extract, upserted, alive)

## Scrape (Inngest on admin)

Production scrape runs in **TypeScript** on `apps/admin` via Inngest (Rust `iptv-worker` is optional/local only).

1. Set on the admin deploy: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `INNGEST_EVENT_KEY`, `INNGEST_SIGNING_KEY` — **do not** set `INNGEST_DEV` on Vercel (that forces localhost Inngest and 502s scrape start)
2. Sync `https://<admin-host>/api/inngest` in the Inngest dashboard
3. Daily cron `0 6 * * *` UTC runs `iptv-catalog-scrape` — toggle **Daily scrape** on/off in Scrape → Automation (`iptv_ops_settings.scrape_cron_enabled`). Off = cron no-ops; manual run still works
4. Reddit listing today is **`r/IPTV_ZONENEW`** (other old catalog subs are banned). Posts are usually base64 → encrypted **paste.sh** links — scrape decrypts those (L2), then runs credential extract
5. **Post storage is id-only** — `iptv_scrape_posts` keeps `post_id` (+ counters/flags), never Reddit title or body text. Candidates link `post_id` the same way.
6. Candidates are upserted after extract. **Xtream `player_api` verify is currently off** (`VERIFY_PORTAL_STATUS = false` in `iptv-catalog-scrape.ts`) — pool rows land as `alive: null` / unverified so Deal will not pick them until verify is re-enabled. Flip the flag to restore per-portal `verify-portal-status-*` steps.

If a run shows **posts > 0** but **L1 = 0**, paste decrypt / deep extract failed (not Inngest itself).

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
