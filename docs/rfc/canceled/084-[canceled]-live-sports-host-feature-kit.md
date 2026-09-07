# RFC-084: Live Sports host feature + kit standard layout

**Status:** canceled  
**Depends on:** [RFC-071](../fixed/071-[fixed]-live-sports-hub-kit.md) · [RFC-073](../fixed/073-[fixed]-live-sports-kit-ownership.md) · [RFC-081](../fixed/081-[fixed]-host-only-platform-nav-defaults.md)  
**Area:** shell / Live Sports / catalog kit

## Status at a glance

| | |
|--|--|
| **Progress** | **Canceled** — superseded by [RFC-087](../fixed/087-[fixed]-live-sports-pack-only.md) |
| **Current slice** | Host core tab rejected — Live Sports is pack-only |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Why canceled

RFC-084 made `live_matches` a **host core** Addons tab (IPTV pattern) so the rail worked without a hub pack. That fights the external-plugins model. **RFC-087** reverses it: hub packs own the tab; foundation keeps schedule/stream services only.

Historical acceptance rows below stay frozen (what shipped under the wrong model).

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R84-C01 | `live_matches` in `coreShellNavIds` + core destination/builder (kit mount, host-default layout) | ✅ |
| 2 | R84-C02 | Host-default layout: `kit.list` + `source: live_schedule` (list, no cards) + streams panel widget | ✅ |
| 3 | R84-C03 | Streams panel (Providers / Live TV) — no full details route on standard path | ✅ |
| 4 | R84-C04 | Pack hub layout overrides host-default when enabled; `syncActiveHubNavIds` never strips core ids | ✅ |
| 5 | R84-C05 | Addons Live Sports = navbar toggle only (IPTV pattern) | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R84-A01 | Addons ON with no Live Sports hub pack → Live Sports tab visible | ✅ |
| 2 | R84-A02 | Core builder mounts kit / `LiveSportsHubPage` with host-default layout (not `KitShellLoader`) | ✅ |
| 3 | R84-A03 | Browse is dense match list — not card grid | ✅ |
| 4 | R84-A04 | Match select opens right streams panel (Providers / Live TV); no details route | ✅ |
| 5 | R84-A05 | Play from panel uses native player only | ✅ |
| 6 | R84-A06 | Enabled hub with `nav.tabId: live_matches` replaces builder with pack `KitShell` layout | ✅ |
| 7 | R84-A07 | Disabling hub pack does not strip `live_matches` from navbar when user kept it visible | ✅ |
| 8 | R84-A08 | Feature doc + changelog describe host feature + list/panel | ✅ |
| 9 | R84-A09 | TV: D-pad walks dense match list + side streams panel (chrome, tabs, cats, cards); ←/→ between list and panel | ✅ |
| 10 | R84-A10 | Settings → Merge matching events default off; soft/ESPN merge skipped until enabled | ✅ |
| 11 | R84-A11 | Viewer hydrate batches into totals map without invalidating grid merge cache / remapping all matches | ✅ |

---

## Summary

Live Sports is a **host product addon** (Settings → Addons), same class as IPTV — not a pack-gated hub tab.

| Layer | Owns |
|-------|------|
| **Interface** | Schedule list, select match, Providers / Live TV resolve, native play |
| **Standard** | Core tab + host-default kit layout (list + streams panel) |
| **Pack example** | Optional hub `layout` redesigns chrome; host still owns resolve/play |

RFC-081 still forbids baking Anime / Asian Drama / etc. into `PlatformDefaults`. **Exception:** `live_matches` joins `iptv` / `settings` in `coreShellNavIds` (visibility still via Addons / Features prefs — not forced on fresh install).

### Related

- [Issue 220](../issues/canceled/220-[canceled]-live-sports-addon-nav-without-hub-pack.md)
- [Live Matches feature](../features/live/live-matches.md)
- [RFC-081](fixed/081-[fixed]-host-only-platform-nav-defaults.md)
