# IPTV — Catalog ops (admin)

> Central scrape pool, credits, and admin tools for IPTV portal inventory (operators only).

## What it is

Operators scrape Reddit IPTV posts, mark rows on shared **`iptv_portals`** with `catalog_pool = true`, grant **credits**, and let users **deal** packs of portals. End users do not use this console — they use the Forja app / Account portal. There is no separate candidates table.

## How to open it

1. Apply migrations `20260718224617_iptv_catalog_ops.sql` and `20260718225349_iptv_catalog_region_ops.sql` on the Forja Supabase project
2. Set `accounts.is_admin = true` for your operator account
3. From `apps/admin`: `pnpm install`, `pnpm dev` → **http://127.0.0.1:4000**
4. Sign in with the same Auth + Turnstile stack as the user portal (same Supabase project)

## What you can do

- **Dashboard** — pool alive/dead/unchecked, credits, region breakdown, latest run funnel (posts / L1 / deep / L2 / upserted / duration), recent runs table. A stats strip under the nav repeats pool + latest run on every admin page
- **Accounts** — search by email; credits stepper (−1 / +5) and Find Portals switch inline per row. Expand a row to see assigned portals, unassign, or **Assign portal** (any portal → pick profile; optional burn 1 credit / bump `dealt_count`)
- **Pool** — table of hosts (one line: host / accounts / alive / scraped); expand to a 2-column portal grid (Account→IPTV row content, actions on hover). **User+** opens who has that portal + assign/unassign. Filter by **status** (alive / dead / unchecked) and **region**. **Check status** (radio icon) on a portal or on the host row runs Xtream `player_api` and updates alive/expiry/region. Start/stop scrape from the bar
- **Scrape** — run history updates live (run row created on Start; realtime + fast poll). Refresh / Stop / Mark stuck apply immediately in the UI
- **Providers** — edit remote provider runtime config (templates, APIs, WebStreamr bases, anime hosts/mirrors, CDN Referer rules) via form sections or raw JSON

## Scrape (Inngest on admin)

Production scrape runs in **TypeScript** on `apps/admin` via Inngest (Rust `iptv-worker` is optional/local only).

1. Set on the admin deploy: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `INNGEST_EVENT_KEY`, `INNGEST_SIGNING_KEY` — **do not** set `INNGEST_DEV` on Vercel (that forces localhost Inngest and 502s scrape start)
2. Sync `https://<admin-host>/api/inngest` in the Inngest dashboard
3. Scheduled scrape: Inngest ticks every minute; the real schedule is **`iptv_ops_settings.scrape_cron`** (UTC 5-field cron, default `0 6 * * *`). Edit it in Scrape → Automation (presets / hour-minute / cron + human label). Toggle **Scheduled scrape** via `scrape_cron_enabled` — off = ticks no-op; manual run still works
4. Reddit listing today is **`r/IPTV_ZONENEW`** (other old catalog subs are banned). Posts are usually base64 → encrypted **paste.sh** links — scrape decrypts those (L2), then runs credential extract
5. **Post storage is id-only** — `iptv_scrape_posts` is just `post_id` (+ subreddit / run). No title/body; deep_refs table removed.
6. Extract upserts into **`iptv_portals`** with `catalog_pool = true`. **Xtream `player_api` verify is off** in the scrape job (`VERIFY_PORTAL_STATUS = false`); use Pool → Check status for manual probes. Deal only assigns `catalog_pool` rows with `alive = true`.

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

**Lotto:** weighted random among eligible pool rows (`1/(1+dealt_count)`, 1.5× if checked in the last 7 days). Prefers distinct hosts in the pack, then fills if the pool is thin. Empty pack refunds the credit.

In the Forja app: IPTV → Portals → **Deal** — one tap spends 1 credit for up to 5 portals (region `ANY`). Account → IPTV on the web shows the credit balance (deal itself stays in-app).

## Tips

- **Separate app** from the user portal (`apps/web`), but **same** TanStack Start stack, Forja design tokens/UI, AuthProvider, and Turnstile
- Stalker/MAC notes are skipped by extract (Xtream only)
- With `scrape --verify`, region is guessed from timezone + live category names
- Agents must **not** run `supabase db reset` or `db push` unless you explicitly approve in chat

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [RFC-040](../../rfc/040-[open]-iptv-catalog-ops.md)
- [apps/admin README](../../../apps/admin/README.md)
