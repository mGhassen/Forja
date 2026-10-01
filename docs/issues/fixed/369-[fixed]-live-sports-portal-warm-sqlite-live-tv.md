# Issue 369: Live Sports portal warm + SQLite Live TV match

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Live Sports · Portals · Live TV · IPTV catalog SQLite

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 2** acceptance |
| **Current slice** | Warm live shelf on portal select; Live TV candidates from SQLite |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I369-T01 | Portal card `shelfLoading` full-card stripe overlay (foundation + inventory) | ✅ |
| 2 | I369-T02 | Portals select/change warms live section into IPTV SQLite shelf | ✅ |
| 3 | I369-T03 | `sport_match` `get_or_fetch_portal_live` prefers catalog_db live shelf (API fallback) | ✅ |
| 4 | I369-T04 | `PortalLiveTvSearch` ensures shelf before match; invalidates cache on portal change | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I369-A01 | Selecting an Xtream/Stalker portal from Live Sports Portals shows card stripes until the live channel shelf is ready | ✅ |
| 2 | I369-A02 | Live TV match uses the local live shelf when present (broadcast + EPG ranking unchanged); cold miss still fetches the portal API | ✅ |

---

## Summary

**Gap:** Portals select flipped the active portal but did not warm the IPTV SQLite live shelf. Live TV still fetched the full live catalog over the network into a short RAM cache, separate from IPTV browse paging.

**Fix:** On select, warm the live shelf (with a full-card stripe while loading). `sport_match_streams` reads candidates from that shelf when present; otherwise keeps the Xtream/Stalker fetch + RAM cache. Host Live TV search ensures the shelf before matching and clears its result cache when the active portal changes.

## Related

- [364](364-[fixed]-live-sports-live-tv-misses-channels.md) — restore Rust matcher
- [RFC-116](../../rfc/fixed/116-[fixed]-local-storage-kv-sqlite.md) — IPTV `catalog.sqlite` shelves
- [live-sports feature](../../features/live/live-sports.md)
