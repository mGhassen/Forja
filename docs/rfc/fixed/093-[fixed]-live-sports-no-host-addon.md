# RFC-093: Live Sports — no host Addons row

**Status:** fixed  
**Depends on:** [RFC-087](087-[fixed]-live-sports-pack-only.md) · [RFC-089](089-[fixed]-pack-addon-settings.md) · [RFC-092](092-[fixed]-delete-root-app-live-sports.md)  
**Area:** Settings → Addons, Forja Packs, sync, web portal

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **5 / 5** components · **10 / 10** acceptance |
| **Current slice** | **Complete** — host Addons → Live Sports removed; pack enable is the gate |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R93-C01 | Remove Live Sports from app + web Addons catalogs | ✅ |
| 2 | R93-C02 | Pack `settings.fields` render under Forja Packs (addon id optional) | ✅ |
| 3 | R93-C03 | Live catalog/provider caps under Forja Packs only | ✅ |
| 4 | R93-C04 | Retire `addon_feature_live_sports` product gate (app + sync + web) | ✅ |
| 5 | R93-C05 | Feature docs + changelog | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R93-A01 | No Live Sports row in Settings → Addons (`kSettingsAddons`) | ✅ |
| 2 | R93-A02 | No Live Sports row / route on web Addons | ✅ |
| 3 | R93-A03 | Hub Setup fields show under Forja Packs when pack enabled | ✅ |
| 4 | R93-A04 | `settings.addon` optional; fields alone parse | ✅ |
| 5 | R93-A05 | Portal sports config resolves settings plugin without host addon id | ✅ |
| 6 | R93-A06 | No `liveSportsNav` / `addon_feature_live_sports` gate for product | ✅ |
| 7 | R93-A07 | Sync ignores / strips live sports addon feature keys | ✅ |
| 8 | R93-A08 | Live Sports tab still comes only from hub pack `nav` | ✅ |
| 9 | R93-A09 | Feature docs point at Forja Packs, not Addons → Live Sports | ✅ |
| 10 | R93-A10 | Changelog notes removal of host Addons row | ✅ |

---

## Summary

RFC-087 made Live Sports pack-only for chrome, but left **Settings → Addons → Live Sports** as a host capability bucket (`addon_feature_live_sports` + RFC-089 `settings.addon: live_sports`). That is still a host product surface.

**Rule:** Live Sports is not a host Addons row. Pack install/enable is on/off. Setup and live catalog toggles live under **Forja Packs**. IPTV remains a host Addons row.

Frozen history: RFC-087 A06 and RFC-089 A02 stay ✅; this RFC owns the cut.

### Related

- [live-matches](../../features/live/live-matches.md)
- [forja-sports](../../features/settings/forja-sports.md)
