# 335 — HDHub4u empty Sources (stale base + dead HubCloud rewrite)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/hdhub4u.js` · `domains.json` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I335-T01 | Point SPECS / domains.json / host `sourceHosts` at live `new6.hdhub4u.cl` (`.af` / `.limo` dead) | ✅ |
| 2 | I335-T02 | Stop rewriting HubCloud drives onto dead `hubcloud.dad`; keep / map to `hubcloud.ist` | ✅ |
| 3 | I335-T03 | Follow `greenmotors` → `hblinks` intermediate pages that list HubDrive / HubCloud | ✅ |
| 4 | I335-T04 | Providers pack 1.6.8 + feature/changelog docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I335-A01 | curl: Typesense hit for `tt1375666` rewrites to `new6.hdhub4u.cl` and title page returns HubDrive / greenmotors quality links | ✅ |
| 2 | I335-A02 | curl: `hubdrive.pics` → `hubcloud.ist` download page yields PixelServer / 10Gbps file URLs (not blank `.dad`) | ✅ |
| 3 | I335-A03 | App: Sources → HDHub4u lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

Search still works via `search.pingora.fyi`, but permalinks pointed at dead `new1.hdhub4u.af`. The pack fallback base and host `sourceHosts` (`new1.hdhub4u.limo` → parking `hdhub4u.bi`) were stale; live site is **`https://new6.hdhub4u.cl`**.

Separately, HubCloud extraction rewrote every drive URL to **`hubcloud.dad`**, which is a “Coming Soon” parking page. Live drives are on **`hubcloud.ist`**. Quality buttons also gate through **`greenmotors.club` → `hblinks.lol`**, which the extractor skipped after one redirect.

**Root fix:** update bases + HubCloud host map + intermediate link-page scrape. Not a workaround.
