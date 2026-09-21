# 307 — Web Addons list + pack settings parity

**Priority:** P1  
**Severity:** High  
**Status:** open  
**Area:** web Profile → Addons · RFC-089 pack settings · cloud sync  
**Reported:** 2026-09-21

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I307-T01 | Web Addons hub matches app host list (no host IPTV / `addon_feature_iptv` master) | ✅ |
| 2 | I307-T02 | Discover pack-contributed Addons rows from enabled profile packs (`settings.addon`) | ✅ |
| 3 | I307-T03 | Pack addon detail pages render non-secret pack settings fields | ✅ |
| 4 | I307-T04 | Cloud `connectedServices.packSettings` compact/expand on web | ✅ |
| 5 | I307-T05 | Flutter export/import pack settings ↔ `PackSettingsStore` (no secrets) | ✅ |
| 6 | I307-T06 | Local pack-settings writes schedule sync push | ✅ |
| 7 | I307-T07 | Feature docs + changelog describe web Addons discovery + synced pack settings | ✅ |
| 8 | I307-T08 | Debrid / password fields stay app-only on web (honest copy) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I307-A01 | With IPTV + Live Sports packs enabled, web Addons lists Playback, torrent, Stremio, Nuvio, then IPTV + Live Sports (no always-on IPTV unlock switch) | ⬜ |
| 2 | I307-A02 | Web Addons → Live Sports shows Setup toggles; save lands in app after soft-pull | ⬜ |
| 3 | I307-A03 | Web Addons → Debrid explains API keys stay in the app | ⬜ |
| 4 | I307-A04 | App Addons → My List hub_select edits push to web and round-trip | ⬜ |

---

## Summary

Web **Profile → Addons** still hardcodes IPTV as a host row with `addon_feature_iptv`, while the app discovers pack buckets (IPTV, Debrid, Live Sports, My List) from enabled packs and renders RFC-089 fields via `PackAddonSettingsSection`. Pack field values were device-local only (`PackSettingsStore`), so the portal could not show or edit them.

**Root fix:** discover pack rows on web like the app; sync non-secret pack settings under `connectedServices.packSettings`; keep passwords / LAN / Connected services device-bound with honest copy.

**Related:** [RFC-089](../rfc/fixed/089-[fixed]-pack-addon-settings.md) · [RFC-093](../rfc/fixed/093-[fixed]-live-sports-no-host-addon.md) · [cloud sync](../features/settings/cloud-sync.md)
