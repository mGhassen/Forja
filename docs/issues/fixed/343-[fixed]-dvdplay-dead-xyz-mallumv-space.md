# 343 — DVDPlay empty Sources (dead dvdplay.xyz)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/dvdplay.js` · `mallumv.js` · `domains.json` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I343-T01 | Retarget DVDPlay SPECS / domains.json at live `mallumv.space` (`dvdplay.xyz` has no DNS) | ✅ |
| 2 | I343-T02 | Scrape `search.php` → `/movie/` → `/internal/` quality pages (not HubCloud on the title page) | ✅ |
| 3 | I343-T03 | Resolve Pixeldrain + HubCloud (`hubcloud.ist` → `hubcloud.php` → R2 / PixelServer / 10Gbps) | ✅ |
| 4 | I343-T04 | Point MalluMV base at `mallumv.space`; Providers pack 1.6.13 + feature/changelog docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I343-A01 | curl: `mallumv.space/search.php?q=Premalu` hits title page; `/internal/` yields Pixeldrain + HubCloud | ✅ |
| 2 | I343-A02 | curl: HubCloud `hubcloud.php` page yields playable R2 / Pixeldrain file URLs | ✅ |
| 3 | I343-A03 | App: Sources → DVDPlay lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

DVDPlay searched `https://dvdplay.xyz/search.php?q=` — that host no longer resolves. The DVDPlay / MalluMV catalog now lives on **`https://mallumv.space`** (home title still brands DVDPLay). Title pages list `/internal/…` quality rows; file hosts (Pixeldrain, HubCloud) sit on those download pages, not on the movie page itself.

**Root fix:** retarget base + scrape the live search → internal → Pixeldrain/HubCloud chain. MalluMV SPECS base updated the same way (`.gay` redirected and broke search). Not a workaround.

### Related

- [344 MalluMV stale /confirm/](344-[fixed]-mallumv-stale-confirm-internal-scrape.md)
- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)
- [stream providers](../../features/sources/stream-providers.md)
- [335 HDHub4u domain/host churn](335-[fixed]-hdhub4u-stale-base-hubcloud-dad.md)
