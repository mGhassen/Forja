# 142 — IPTV admin scrape: watermark + deep refs + no upsert cap

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/admin` Inngest catalog scrape · `apps/web/supabase/` · RFC-040

## Status at a glance

| | |
|--|--|
| **Progress** | **16 / 16** fix · **0 / 3** acceptance |

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
| 13 | I142-T13 | Stream EOF root: never memoize portal arrays / known-id sets; bulk junction insert; promote from DB ids | ✅ |
| 14 | I142-T14 | Drop `paste_body` — persist `paste_url` only; admin + process fetch paste on demand | ✅ |
| 15 | I142-T15 | Host+user+pass never platform=m3u — get.php type/output stay metadata; backfill misclassified rows | ✅ |
| 16 | I142-T16 | Stream EOF relapse: `streaming: false` on Nitro/Node; claim-next process + paged promote (no id lists in memo) | ✅ |

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

**Also (I142-T15):** extract used to set `platform=m3u` whenever get.php `type`/`output` contained `m3u` — wrong. Host+user+pass is always **xtream**; `type`/`output` stay scrape metadata. Migration `20260806152419_…` flips misclassified pool + deep_ref_portal rows (keeps real `__m3u__` playlist rows).

**HTTP 504 / “before the SDK responded”:** not Reddit — Vercel/proxy killed a long Inngest step. Pipeline is **collect → process → promote**: (1) Reddit pages → posts + deep_ref stubs; L1 candidates upserted inside collect (slim step return); watermark via per-post DB lookup (no known-id set in memo); (2) **claim-next** pending deep_ref → paste + extract + **bulk** `iptv_scrape_deep_ref_portals` insert (counts only in memo — never a pending-id array); (3) **paged** junction ids from DB → chunked catalog promote (never memoize the full portal-id list). Classic orchestration (`checkpointing: false` + `sleep('0s')`). Serve uses **`streaming: false`** — Remix streaming is Edge-only; on Nitro/Node the heartbeat stream truncates → `unexpected end of JSON input` (I142-T16). Returning full portal arrays / known-post / id lists through `step.run` also truncated the body even after T12–T13.

**Apply migrations** `20260731184207_…` + `20260731184812_…` + `20260801115640_…` + `20260804001433_iptv_portals_drop_scrape_provenance.sql` + `20260806151925_iptv_scrape_deep_ref_portals_meta.sql` + `20260806151710_iptv_scrape_deep_refs_drop_paste_body.sql` before deploying admin (ask before `db push`). Junction meta for slim promote; deep refs never store paste plaintext — only `paste_url`. `iptv_portals.post_id` / `layer` stay dropped — scrape lineage via `portal_id`.
