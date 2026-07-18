# IPTV — Catalog ops (admin)

> Central scrape pool, credits, and admin tools for IPTV portal inventory (operators only).

## What it is

Operators scrape Reddit IPTV posts with a Rust worker, store verified portals in a shared **catalog pool**, grant **credits**, and let users later **deal** packs of portals. End users do not run this console — they use the Forja app / Account portal.

## How to open it

1. Apply migration `20260718224617_iptv_catalog_ops.sql` on the Forja Supabase project
2. Set `accounts.is_admin = true` for your operator account
3. From `apps/admin`: copy `.env.example` → `.env` (same Supabase URL/key as `apps/web`), `npm install`, `npm run dev` → http://localhost:5174
4. Sign in with the admin account

## What you can do

- **Dashboard** — pool size, alive count, scrape runs, account count
- **Accounts** — search by email; toggle `iptvScrape`; grant/revoke credits (+5 / −1)
- **Pool** — browse candidates (url, user, alive, region, dealt count; no passwords)
- **Scrape** — view worker run history (pages, L1 extract, upserted, alive)

## Worker (scrape)

```bash
cd crates
export SUPABASE_URL=…
export SUPABASE_SERVICE_ROLE_KEY=…
cargo run -p iptv-worker -- scrape --dry-run --max-pages 2
cargo run -p iptv-worker -- scrape --max-pages 10 --verify
```

`--verify` calls each portal’s `player_api.php` before upsert. Use service role only on a trusted machine.

## Deal (API)

Authenticated users with credits call RPC `deal_iptv_portals(profile_id, region, count)` (default region `ANY`, count `5`). Burns **1 credit**, assigns up to N alive pool portals into `user_iptv_portals`.

In the Forja app: IPTV → Portals → **Deal** (dice icon) — pick a region, spend 1 credit for up to 5 portals. Credit balance shows next to the Portals header when signed in. Account → IPTV on the web shows the credit balance (deal itself stays in-app).

## Tips

- Same Supabase as Forja — do not invent a second database for the pool
- Stalker/MAC notes are skipped by extract (Xtream only)
- With `scrape --verify`, region is guessed from timezone + live category names (`TR` / `US` / `UK` / `EU` / … / `MIXED` / `UNKNOWN`)
- Worker writes L1 posts + L2 deep-ref rows (`iptv_scrape_posts` / `iptv_scrape_deep_refs`) for funnel metrics
- Client **Find Portals** still works when `iptvScrape` is on; pool/deal is the long-term path
- Agents must **not** run `supabase db reset` or `db push` unless you explicitly approve in chat

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [RFC-040](../../rfc/040-[open]-iptv-catalog-ops.md)
- [apps/admin README](../../../apps/admin/README.md)
