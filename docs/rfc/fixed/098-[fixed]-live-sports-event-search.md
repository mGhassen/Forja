# RFC-098: Live Sports event search (top-bar)

**Status:** fixed  
**Depends on:** [RFC-071](071-[fixed]-live-sports-hub-kit.md) · [RFC-095](095-[fixed]-foundation-design-data-split.md)  
**Area:** `shared/foundation/` kit top bar + `live_schedule` list filter

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **6 / 6** acceptance |
| **Current slice** | Shipped — Search left of Portals; client-side filter |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R98-C01 | Session `eventQuery` provider + match helper (no feed reload) | ✅ |
| 2 | R98-C02 | Expanding search chrome next to Portals on kit top bar | ✅ |
| 3 | R98-C03 | Filter dense list / match cards by query; empty + Cmd/Ctrl+F | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R98-A01 | Search control sits left of Portals on Live Sports / Cards top bar | ✅ |
| 2 | R98-A02 | Typing filters visible matches (title / teams / sport) without re-scraping | ✅ |
| 3 | R98-A03 | Sport category bar still uses the full unfiltered schedule for chips | ✅ |
| 4 | R98-A04 | Empty search shows a clear “no matches” copy | ✅ |
| 5 | R98-A05 | TV: D-pad focus Search → Portals; field uses browse/edit split | ✅ |
| 6 | R98-A06 | Feature doc + changelog updated | ✅ |

---

## Summary

Add an IPTV-style expanding **Search** control on the Live Sports kit top bar (right cluster, left of **Portals**) so users can filter the loaded schedule by event name / teams without another catalog fetch.
