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

- **Dashboard** — pool alive/dead/unchecked, credits, region breakdown, latest run funnel (new posts / portals / deep / L2 / unparsed / upserted), recent runs table. A stats strip under the nav shows **All** (every `iptv_portals` row) + pool health + latest run on every admin page
- **Accounts** — search by email; credits stepper (−1 / +5); **Features** chip column opens a dialog with per-flag toggles (`iptvScrape` / Find Portals, `dealPortal` / Deal — each has its own admin RPC). Expand a row to see assigned portals (same card layout as Pool: expiry / status / username / pool badge / URL / max seats + profile pill), unassign, or **Assign portal** (any portal → pick profile; optional burn 1 credit / bump `dealt_count`)
- **Pool** — lists **all** `iptv_portals`. Filter **Inventory** (All / Deal pool / Not in pool; default All). Catalog-pool rows show a **pool** badge; trash removes from catalog pool only (row stays). Host table (host / accounts / alive / scraped); expand for portal grid. **User+** opens who has that portal + assign/unassign. Also filter by **status** / **region**. **Check status** runs Xtream `player_api`. Header link jumps to **Scrape** for start/stop
- **Scrape** — start/stop/mark stuck + run history (live; realtime + fast poll). **Run normal** = only new posts since last watermark. **Run full** = in-app dialog to pick page count (shows ≈ posts; 10 posts/page), then ignore known posts and re-extract. Schedule under Automation.
- **Deep refs** — all base64 / paste refs from scrape. Expand a row to see raw base64/URL, decoded or paste body, and every portal found with **New insert** vs **Already in DB** (url+user existed before that hit)
- **Providers** — edit remote provider runtime config (templates, APIs, WebStreamr bases, anime hosts/mirrors, CDN Referer rules) via flat editable tables or raw JSON

## Scrape (Inngest on admin)

Production scrape runs in **TypeScript** on `apps/admin` via Inngest (Rust `iptv-worker` is optional/local only).

1. Set on the admin deploy: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `INNGEST_EVENT_KEY`, `INNGEST_SIGNING_KEY` — **do not** set `INNGEST_DEV` on Vercel (that forces localhost Inngest and 502s scrape start)
2. Sync `https://<admin-host>/api/inngest` in the Inngest dashboard
3. Scheduled scrape: Inngest has a **daily 06:00 UTC** kick plus a minute tick. The real schedule is **`iptv_ops_settings.scrape_cron`** (UTC 5-field cron, default `0 6 * * *`) with **due/catch-up** (a late tick still runs once per slot; source `inngest-cron`). Edit it in Scrape → Automation. Toggle **Scheduled scrape** via `scrape_cron_enabled` — off = ticks no-op; manual run still works
4. Reddit listing today is **`r/IPTV_ZONENEW`** (other old catalog subs are banned). Posts are usually base64 → encrypted **paste.sh** links — scrape decrypts those (L2), then runs **mechanical** credential extract (get.php, status cards, table dumps, `Portal`+user/pass sheets, stalker `Portal`/`MAC Addr`/`Exp date` cards). Optional LLM agent is **off unless** `IPTV_LLM_EXTRACT=1` + API key (and never fails the run). Every platform upserts into the deal pool; deep-ref rows keep **`type`** + full **`output`**. **alive** stays null until Pool → Check status.
5. **Watermark** — walks `/new` **page by page** (10 posts per Inngest step, newest → older) and **stops at the first `post_id` already in `iptv_scrape_posts`**. Only **new** posts are processed. `posts_seen` on a run = new posts this run (not “500 every time”)
6. **Two phases** — **Collect:** Reddit pages → posts + deep_ref stubs (base64 + paste_url, no paste HTTP). **Process:** load pending stub **ids** from DB → each ref is paste fetch + extract (no portal link RPCs), then a separate **link** step writes `iptv_scrape_deep_ref_portals`. Catalog upsert is a later chunked phase. Inngest uses classic orchestration (`checkpointing: false` + `step.sleep('0s')` yields) — v4 checkpoint streaming was truncating responses (`unexpected end of JSON input`). Full scrape dialog: presets `1–N`, or custom range `5-10` (skip to 5th page, scrape through 10th).
7. **Posts** (`iptv_scrape_posts`) = `post_id` + `subreddit` only. **Deep refs** = **`base64` + `paste_url`**. **Portals** under a ref = **`platform`** + get.php **`type`** / **`output`** + url/user/pass. Promote copies **url/user/pass + `platform`** into `iptv_portals` (RFC-051). get.php `type`/`output` stay on the scrape hit only. No `post_id` / `layer` on product rows. All three platforms upsert when credentials exist.
8. Extract upserts **all** unique portals into **`iptv_portals`** with `catalog_pool = true` (conflict on url+username). No product upsert cap. **Xtream `player_api` verify is off** in the scrape job (`VERIFY_PORTAL_STATUS = false`); use Pool → Check status for manual probes. Deal only assigns `catalog_pool` rows with `alive = true`

If a run shows **new posts > 0** but **portals = 0**, paste decrypt / deep extract failed (not Inngest itself). Check `iptv_scrape_deep_refs` where `needs_recheck`.

**Apply migrations** (ask before `db push`) — keep concerns separate:
- `20260804001433_…` — drop `post_id`/`layer`; owns `upsert_iptv_catalog_candidate` (incl. `p_platform` on promote)
- `20260804135834_…` — user `upsert_iptv_portal` / `get_iptv_portals` + `platform` column (idempotent)

Local:

```bash
cd apps/admin && pnpm dev   # :4000
npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest
# Invoke iptv-catalog-scrape or send event iptv/catalog.scrape
# Optional data: { "maxPages": 100 }  # Reddit pages of 10 posts; watermark usually stops earlier
```

Optional local Rust (on hold for cron):

```bash
cd crates
export SUPABASE_URL=…
export SUPABASE_SERVICE_ROLE_KEY=…
cargo run -p iptv-worker -- scrape --verify
```

## Deal (API)

Requires account feature **`dealPortal`** (default off; admin enables via Accounts → Features) **and** at least 1 credit. Authenticated users call RPC `deal_iptv_portals(profile_id, region, count)` (default region `ANY`, count `5`). Burns **1 credit**, assigns up to N alive pool portals into `user_iptv_portals`. RPC raises `deal portal not enabled` when the flag is off.

**Lotto:** weighted random among eligible pool rows (`1/(1+dealt_count)`, 1.5× if checked in the last 7 days). Prefers distinct hosts in the pack, then fills if the pool is thin. Empty pack refunds the credit.

In the Forja app: IPTV → Portals → **Deal** (hidden unless `dealPortal` is on) — one tap spends 1 credit for up to 5 portals (region `ANY`). Account → IPTV on the web shows the credit balance only when Deal is enabled (deal itself stays in-app).

## Tips

- **Separate app** from the user portal (`apps/web`), but **same** TanStack Start stack, Forja design tokens/UI, AuthProvider, and Turnstile
- Stalker / MAC / M3U notes are kept (platform + type + full outputs on deep refs; all upsert into the pool). Mechanical extract covers `MAC Addr:` / `Exp date:` cards, bare MAC dumps under a `/c/` portal line (`MAC [Total US CA UK Other] [date]` → region tags), `Portal:` + `user pass (Bitiş: …)` sheets, and bare / labeled `.m3u` / `.m3u8` playlist URLs (username `__m3u__`). LLM extract is opt-in only (`IPTV_LLM_EXTRACT=1`) and does not fail the scrape.
- With `scrape --verify`, region is guessed from timezone + live category names
- Agents must **not** run `supabase db reset` or `db push` unless you explicitly approve in chat

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [RFC-040](../../rfc/040-[open]-iptv-catalog-ops.md)
- [apps/admin README](../../../apps/admin/README.md)
