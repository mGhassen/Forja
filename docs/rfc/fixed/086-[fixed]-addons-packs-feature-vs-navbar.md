# RFC-086: Addons/Packs flag features; Features flags navbar

**Status:** fixed  
**Depends on:** [RFC-081](081-[fixed]-host-only-platform-nav-defaults.md), [RFC-084](../084-[open]-live-sports-host-feature-kit.md)  
**Area:** settings / shell / sync

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** components · **16 / 16** acceptance |
| **Current slice** | Web pack install → Features rail default-on |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R86-C01 | `addon_feature_iptv` / `addon_feature_live_matches` KV + migration from prior one-bit nav | ✅ |
| 2 | R86-C02 | Addons ON/OFF: feature flag + default rail on; OFF strips rail | ✅ |
| 3 | R86-C03 | Features inventory from addon flags + pack destinations; Features hide/reorder | ✅ |
| 4 | R86-C04 | Packs mark known hubs; first-seen / pack activate defaults Features rail on | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R86-A01 | Addons IPTV ON → Features lists IPTV OFF; rail unchanged until Features ON | ✅ |
| 2 | R86-A02 | Features IPTV ON → rail shows IPTV; Addons switch stays on | ✅ |
| 3 | R86-A03 | Addons IPTV OFF → feature leaves Features and rail | ✅ |
| 4 | R86-A04 | Hub pack enable → Features lists hub OFF; Features ON puts hub on rail | ✅ |
| 5 | R86-A05 | Upgrade: existing `iptv`/`live_matches` in `visibleIds` set addon feature flags true without clearing rail | ✅ |
| 6 | R86-A06 | Cloud prefs sync addon feature bools; navigation sync stays Features `visibleIds` | ✅ |

---

## Acceptance (default-on activate)

Supersedes R86-A01 / R86-A04 for activate UX — frozen rows stay historical.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 7 | R86-A07 | Addons IPTV / Live ON → feature flag on **and** Features rail on by default | ✅ |
| 8 | R86-A08 | Pack / hub plugin ON → hub Features rail on by default (first-seen + re-enable) | ✅ |
| 9 | R86-A09 | Features can still hide a tab while Addon / pack stays on | ✅ |

---

## Acceptance (web portal contract)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 10 | R86-A10 | Web Addons IPTV / Live writes `addon_feature_*` + default rail `visibleIds` (same as app) | ✅ |

---

## Acceptance (derived inventory + clean sync)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 11 | R86-A11 | Features inventory = addon flags ∪ hub tabs from packs — never HOST_CORE / stale `tabOrder` alone | ✅ |
| 12 | R86-A12 | Ordinary prefs push merges playback but omits `addon_feature_*`; only intentional Addons push overlays those keys | ✅ |
| 13 | R86-A13 | Pack remove prunes hub ids from cloud `tabOrder` / `visibleIds`; Addons OFF drops host ids from Features list | ✅ |
| 14 | R86-A14 | Web Addons IPTV / Live: single `patch({ playback, navigation })` using nextAvailable — no parallel commit prune race | ✅ |
| 15 | R86-A15 | Web Features inventory/hydrate uses cloud playback + packs (not empty playDraft); never-stored available ids default-on | ✅ |
| 16 | R86-A16 | Web Forja pack add/remove updates navigation via `navigationAfterForjaPacksChange`; Features does not prune-on-hydrate | ✅ |

---

## Summary

Split **feature availability** from **navbar visibility**.

| Layer | Meaning | Navbar on activate |
|-------|---------|-------------------|
| **Addons** | IPTV / Live Sports system exists | Defaults Features rail **on** |
| **Packs** | Hub feature exists | Defaults Features rail **on** (first-seen / enable) |
| **Features** | Show on rail / order / star | User hide/reorder after defaults |

**Availability** is derived (`addon_feature_*` + pack hub tab ids). `navigation.tabOrder` / `visibleIds` only order and show among available ids — they must not invent IPTV / Live / Asian Drama when Addons/packs are off.

Addon / pack **OFF** removes the feature from Features and the rail.

### Related

- [Features settings](../../features/settings/navigation-bar.md)
- [Issue 224](../../issues/224-[open]-android-tv-addons-iptv-live-toggle-dead.md)
