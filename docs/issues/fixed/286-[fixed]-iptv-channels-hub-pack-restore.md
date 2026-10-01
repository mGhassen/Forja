# Issue 286: Restore IPTV Channels hub (pack curated brands + portal scan)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV hub · pack Channels section · [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I286-T01 | Curated brand inventory in pack (`channels.json` / `_channels_data.js`) — not empty host `HardcodedChannels` | ✅ |
| 2 | I286-T02 | Pack `section=channels` feed: kinds rail + scan vault portals for keyword hits | ✅ |
| 3 | I286-T03 | Host chrome re-queries on Channels category/sort/search (`packChromeVodPagedFeed`) | ✅ |
| 4 | I286-T04 | Catalog shelf **Channels** + loading copy; changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I286-A01 | IPTV shelf **Channels** shows curated brands in the side rail | ⬜ |
| 2 | I286-A02 | Selecting a brand scans saved portals and lists matching live streams (playable) | ⬜ |
| 3 | I286-A03 | Hits cache in vault; Refresh / force re-scans | ⬜ |

---

## Summary

Pre-wipe `IptvView.channelsHub` + `HardcodedChannels` inventory was deleted with the Dart god controller. Host stub `HardcodedChannels.all = []` remained.

**Shipped:** pack-owned Channels section — curated list in the hub pack, scan of the user’s vault portals (legacy steps 1+3+4; no scrape-bootstrap Get More in this slice). No `IptvController` resurrected.

### Related

- [RFC-109](../rfc/109-[open]-forja-pack-product-host.md)
- Recover: `git show a3f86fa13:apps/forja/lib/features/iptv/data/hardcoded_channels.dart`
- Recover scan: `git show 8d456be06^:…/iptv_controller_channels.dart`
