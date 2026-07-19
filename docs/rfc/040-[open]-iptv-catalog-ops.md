# RFC-040: IPTV catalog ops (admin + worker + pool + credits)

**Status:** open  
**Depends on:** [RFC-036](036-[open]-accounts-iptv-profile-settings.md)  
**Area:** `apps/admin/` (UI + Inngest catalog scrape), `apps/web/supabase/`, `crates/iptv/` (Rust worker on hold)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **18 / 20** acceptance (editable scrape cron; AI + Stalker deferred) |
| **Current slice** | Editable `scrape_cron` in admin Automation; AI/Stalker deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R40-C01 | Supabase: scrape posts / deep refs / candidates / credits / deal RPC | ✅ |
| 2 | R40-C02 | Rust `iptv-worker` CLI (scrape → L1/L2 extract → verify → upsert) | ✅ |
| 3 | R40-C03 | `apps/admin` thin React console (`is_admin` gate) | ✅ |
| 4 | R40-C04 | Forja app: Deal N portals + credits UX | ✅ |
| 5 | R40-C05 | Region classifier (timezone + live categories) | ✅ |

---

## Acceptance (foundation)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R40-A01 | Shared Supabase tables for L1 posts, L2 deep refs, catalog candidates | ✅ |
| 2 | R40-A02 | `accounts.iptv_credits` + admin grant/revoke ledger | ✅ |
| 3 | R40-A03 | `deal_iptv_portals(region, n)` assigns from pool into `user_iptv_portals` | ✅ |
| 4 | R40-A04 | Worker can scrape Reddit via `crates/iptv` and write candidates (service role) | ✅ |
| 5 | R40-A05 | Admin UI: accounts list, toggle `iptvScrape`, credits, scrape runs, pool browser | ✅ |
| 6 | R40-A06 | Client Find Portals remains gated by `iptvScrape` (unchanged this slice) | ✅ |
| 7 | R40-A07 | Stalker/MAC payloads skipped (not promoted to pool) | ✅ |
| 8 | R40-A08 | Funnel metrics: L1 extract vs L2 fetch/extract counts on scrape runs | ✅ |
| 9 | R40-A09 | Region tags on candidates (TR/EU/US/UK/MIXED/UNKNOWN) | ✅ |
| 10 | R40-A10 | Forja Deal UX (credit burn + region picker) | ✅ |
| 11 | R40-A11 | AI extract fallback on L2 misses | ⏭️ |
| 12 | R40-A12 | Stalker/Ministra portal type in Forja | ⏭️ |
| 13 | R40-A13 | Ops console under web `/admin` (shared AuthProvider + Forja UI; no separate `apps/admin`) | ✅ |
| 14 | R40-A14 | Separate `apps/admin` TanStack Start app (same stack/auth/design as web; not portal routes) | ✅ |
| 15 | R40-A15 | Inngest TS scrape on `apps/admin` (cron + per-portal `verify-portal-status` step; Rust worker on hold) | ✅ |
| 16 | R40-A16 | Admin Inngest scrape: L2 base64 → paste.sh decrypt + extract (parity with `crates/iptv` deep links); drop banned Reddit subs | ✅ |
| 17 | R40-A17 | Persist Reddit `post_id` only on scrape posts / candidates — never title or body_excerpt | ✅ |
| 18 | R40-A18 | Admin Pool: manual Check status on portal or host (player_api → update alive) | ✅ |
| 19 | R40-A19 | Single `iptv_portals` table + `catalog_pool`; drop `iptv_catalog_candidates` + scrape deep_refs / post body cols | ✅ |
| 20 | R40-A20 | Admin Scrape Automation: edit UTC schedule (presets / time / cron) via `iptv_ops_settings.scrape_cron`; Inngest minute tick matches expression | ✅ |

---

## Summary

Move IPTV discovery off per-user Reddit scrape into a **central ops pipeline**: admin console + Rust worker write a shared catalog pool; users spend **credits** to **deal** portals (lottery pack) filtered by region. Same Supabase as Forja accounts/`iptv_portals` — no second database.

## Goals

1. Admin-only scrape inventory (L1 post + L2 base64/paste).
2. Verify alive before pool eligibility.
3. Credits + deal RPC for fair distribution.
4. Separate TanStack Start admin app (`apps/admin`) — same auth + design system as `apps/web`, not embedded in the user portal.
5. Reuse `crates/iptv` extract/scrape — no Dart engine scrape growth.

## Problem

Per-user Find Portals hits the same `/new` posts, cannot filter catalog region, and races the same credentials. Regex extract is fine for v1; the product gap is **central inventory + deal**, not more client scrape.

## Contracts

- **Pool ≠ user assignment** — same `iptv_portals` row; `catalog_pool` marks deal inventory; `user_iptv_portals` is who has it.
- **L1 / L2** — extract-time only; DB keeps Reddit `post_id` on the portal / scrape_posts, never post body.
- **Worker** uses service role; admin UI uses authenticated `is_admin` RPCs/RLS.
- **No AI in foundation** — optional later on L2 miss samples only.

## Related

- [RFC-036](036-[open]-accounts-iptv-profile-settings.md) — accounts, `iptvScrape`, portals
- [iptv-xtream feature](../features/live/iptv-xtream.md)
- Issue 063 (fixed) — Rust `scrape_page` / extract
