# RFC-072: IPTV VOD catalog details plugin

**Status:** open  
**Depends on:** [RFC-070](070-[partial]-catalog-hub-protocol.md)  
**Area:** `features/iptv/`, `shared/catalog/`, `plugins/iptv/vod/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **6 / 6** acceptance |
| **Current slice** | IPTV VOD on shared hub details kit + external pack |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R72-C01 | `plugins/iptv/vod/` — `iptv-vod` details + `iptv-enrich-tmdb` companion | ✅ |
| 2 | R72-C02 | `catalog_iptv_open.dart` — seed meta, `openIptvVodDetails`, portal resolve | ✅ |
| 3 | R72-C03 | `hub_details_play` IPTV portal play branch; hide Sources for `resolveType: iptv` | ✅ |
| 4 | R72-C04 | Remove custom IPTV detail screens; portal-filtered More Like This on kit | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R72-A01 | IPTV movie/series tap opens `HubDetailsScreen` via `iptv-vod` plugin | ✅ |
| 2 | R72-A02 | Root details are portal-only (title, icon, episodes); TMDB via enrich companion only | ✅ |
| 3 | R72-A03 | Play resolves portal URL in `IptvPtPlayerScreen` — no Sources panel | ✅ |
| 4 | R72-A04 | More Like This intersects portal catalog; taps reopen IPTV hub details | ✅ |
| 5 | R72-A05 | Pack install via `FORJA_HQ_IPTV_VOD_MANIFEST_URL` / `iptv-vod` slot (`plugins/iptv/vod/`) | ✅ |
| 6 | R72-A06 | Host resolves plugin by `types: iptv` — no hardcoded `iptv-vod` in feature code | ✅ |

---

## Summary

IPTV VOD movie/series details use the same **hub details kit** as Home / Anime / Drama. A **details-only** catalog pack (`iptv-vod`) shapes portal snapshot meta; optional **`iptv-enrich-tmdb`** companion adds TMDB match/backdrops/cast/recs. Host prefetches portal episodes (series), seeds `open.surface: iptv` / `resolveType: iptv`, and plays via `IptvClient` — not engine Sources.

Browse (Live / Movies / Series shelves) stays in the Flutter IPTV feature; this RFC is the **details overlay** only.

## Related

- [RFC-070](070-[partial]-catalog-hub-protocol.md) — hub protocol + enrich pipe
- [Issue 162](../issues/162-[open]-iptv-more-like-this-catalog-only.md) — portal-only recs
