# 142 — IPTV admin scrape: watermark + deep refs + no upsert cap

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/admin` Inngest catalog scrape · `apps/web/supabase/` · RFC-040

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 3** acceptance |

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
| 8 | I142-T08 | Page-by-page scrape (10 posts/Reddit page per Inngest step) + paste fetch timeouts | ✅ |

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

**Also (I142-T08):** a full scrape dying at ~10m with truncated error `Your server returned HTTP…` and all metrics `0` is Inngest/proxy killing a single long step. Fixed by **page-by-page** Reddit walk (`limit=10` per step) + paste fetch timeouts — not a Reddit auth failure.

**Apply migrations** `20260731184207_…` + `20260731184812_…` before deploying admin (ask before `db push`).
