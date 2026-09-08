# RFC-093: Live Sports — no host Addons row

**Status:** fixed  
**Depends on:** [RFC-087](087-[fixed]-live-sports-pack-only.md) · [RFC-089](089-[fixed]-pack-addon-settings.md) · [RFC-092](092-[fixed]-delete-root-app-live-sports.md)  
**Area:** Settings → Addons, Forja Packs, sync, web portal

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **6 / 6** components · **10 / 10** acceptance · **3 / 3** discovery slice |
| **Current slice** | **Complete** — pack `settings.addon` invents Addons rows (no host Live Sports product) |

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
| 6 | R93-C06 | Discover pack `settings.addon` → dynamic Addons rows (RFC-089 surface) | ✅ |

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

## Acceptance (discovery slice)

Restores RFC-089 Addons settings surface without a hardcoded host Live Sports product.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R93-A11 | Enabled pack with `settings.addon` invents an Addons row (not in `kSettingsAddons`) | ✅ |
| 2 | R93-A12 | Opening that row shows [PackAddonSettingsSection] fields | ✅ |
| 3 | R93-A13 | Hub restores `settings.addon: live_sports`; no `addon_feature_live_sports` gate | ✅ |

---

## Summary

RFC-087 made Live Sports pack-only for chrome, but left **Settings → Addons → Live Sports** as a host capability bucket (`addon_feature_live_sports` + RFC-089 `settings.addon: live_sports`). That is still a host product surface.

**Rule:** Live Sports is not a **built-in** host Addons row and has no feature-flag gate. Pack install/enable owns the tab. Pack `settings.addon` still feeds **Addons** via discovery (RFC-089) — when the hub is installed you get an Addons settings page; when it is not, the row is gone. Setup also remains on the Forja Packs expand. IPTV remains a host Addons row.

Frozen history: RFC-087 A06 and RFC-089 A02 stay ✅; this RFC owns the cut + discovery correction.

### Related

- [live-matches](../../features/live/live-sports.md)
- [forja-sports](../../features/settings/forja-sports.md)
