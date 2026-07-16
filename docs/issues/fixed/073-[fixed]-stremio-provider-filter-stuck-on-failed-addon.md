# 073 — Stremio provider filter stuck on failed addon (Torrentio 403)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Sources panel · Stremio · `player_sources_panel.dart` · `details_screen_stremio.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I73-T01 | `promoteStremioProviderId` — leave empty/failed addon for first loaded when not user-picked | ✅ |
| 2 | I73-T02 | Player + details: sync provider after each addon result, cache hydrate, and fetch complete | ✅ |
| 3 | I73-T03 | `StremioService._retryGet` — do not retry HTTP 401/403/4xx (except 429) | ✅ |
| 4 | I73-T04 | Unit coverage for promote helper (empty first addon, preferred wait/fallback, user pick) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I73-A01 | Unit: empty Torrentio + loaded YTS → promote to YTS; user pick stays when it has streams | ✅ |
| 2 | I73-A02 | Unit: preferred still fetching → no promote; preferred empty + YTS loaded → YTS | ✅ |
| 3 | I73-A03 | Manual: Stremio with Torrentio Cloudflare 403 + working YTS → list shows YTS rows (not red sticky error) | ⬜ |
| 4 | I73-A04 | Manual: Filters badge does not count the required Stremio provider radio as “1” | ⬜ |

---

## Summary

Sources **Filters → Providers** defaults to the first installed stream addon (often Torrentio). When Torrentio returns **HTTP 403** (Cloudflare challenge on `torrentio.strem.fun`) and another addon (e.g. YTS) returns streams, the panel kept the empty provider selected — especially after session cache hydrate — so the list looked stuck/blank while YTS worked if selected by hand.

**Symptom fix:** promote the provider filter to the first addon that actually returned streams. Do not let a sticky red “No streams found in selected addon” replace the whole list when another addon has rows. Do not count the required Stremio/Torrents provider radio toward the Filters badge. Treat an empty session cache as a miss. Stop retrying hard 4xx on Stremio HTTP so failed addons finish quickly.

**Root / environment:** Torrentio itself is blocked by Cloudflare from some IPs/networks — that is not fixed in-app; users may need a reachable mirror, VPN, or debrid-configured Torrentio URL. The panel no longer hides other addons’ results behind the failed default.
