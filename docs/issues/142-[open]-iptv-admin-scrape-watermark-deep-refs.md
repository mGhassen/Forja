# 142 — IPTV admin scrape: watermark + deep refs + no upsert cap

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/admin` Inngest catalog scrape · `apps/web/supabase/` · RFC-040

## Status at a glance

| | |
|--|--|
| **Progress** | **12 / 12** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I142-T01 | Watermark: process only new `/new` posts; stop at known `post_id` | ✅ |
| 2 | I142-T02 | Always persist `subreddit`; backfill empty rows | ✅ |
| 3 | I142-T03 | Restore `iptv_scrape_deep_refs` + keep unparsed payloads (`needs_recheck`) | ✅ |
| 4 | I142-T04 | Upsert **all** extracted portals (remove `maxVerify` scrape cap; chunk Inngest steps) | ✅ |
| 5 | I142-T05 | Honest run metrics + admin Scrape table labels (`unparsed_count`) | ✅ |
| 6 | I142-T06 | Persist portals per deep ref + `was_existing` (already in pool) | ✅ |
| 7 | I142-T07 | Admin **Deep refs** page: show base64/payload + portals new vs already-in-DB | ✅ |
| 8 | I142-T08 | Page-by-page scrape; persist base64+paste_url before paste fetch | ✅ |
| 9 | I142-T09 | Deep refs = base64+paste_url; portals = platform + get.php type/output | ✅ |
| 10 | I142-T10 | Collect-all Reddit into DB stubs, then process pending deep_refs (no interleaved paste) | ✅ |
| 11 | I142-T11 | Drop scrape provenance (`post_id`, `layer`) from `iptv_portals`; lineage via deep_ref_portals only | ✅ |
| 12 | I142-T12 | Inngest stream EOF: `checkpointing: false`; slim pending ids; process ≠ link portals | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I142-A01 | Manual scrape after watermark: posts ≈ new only; deep_refs rows for b64/paste; unparsed kept when extract=0 | ⬜ |
| 2 | I142-A02 | Run with 100+ unique portals upserts all (not capped at 40); pool grows by new url+user only | ⬜ |
| 3 | I142-A03 | Deep refs page lists refs with expandable payload; portal rows show New insert vs Already in DB | ⬜ |

---

## Summary

Admin catalog scrape rewalked 500 posts every run, wrote empty `subreddit`, dropped deep refs (R40-A19), discarded undecoded/unparsed paste text, and capped upserts at `maxVerify` (default 40) even with verify off.

**Root fix:** resume from known `post_id`s, restore deep-ref storage with retry queue, upsert every portal found, fix subreddit.

**Also (I142-T08/T09):** one deep_ref row = **base64 + paste_url**. Portal hits store **`platform`** (xtream/m3u/stalker) and get.php **`type`/`output`** query params (e.g. `type=m3u_plus&output=m3u8`). Apply migration `20260801115640_…` (truncates old deep_ref rows — re-run full scrape).

**HTTP 504 / “before the SDK responded”:** not Reddit — Vercel/proxy killed a long Inngest step. Pipeline is now **collect then process**: (1) all Reddit pages → `iptv_scrape_posts` + deep_ref stubs; (2) pending **ids** only → `process-deep-ref-N` (paste + extract, no link) → `link-deep-ref-portals-N` → chunked catalog upsert. Classic Inngest orchestration (`checkpointing: false` + `sleep('0s')`); v4 checkpoint streaming was returning empty JSON (`unexpected end of JSON input`).

**Apply migrations** `20260731184207_…` + `20260731184812_…` + `20260801115640_…` + `20260804001433_iptv_portals_drop_scrape_provenance.sql` before deploying admin (ask before `db push`). The latest drops `iptv_portals.post_id` / `layer` — scrape lineage stays on `iptv_scrape_*` via `portal_id`.
