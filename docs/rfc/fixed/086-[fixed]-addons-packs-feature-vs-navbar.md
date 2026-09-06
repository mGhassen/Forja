# RFC-086: Addons/Packs flag features; Features flags navbar

**Status:** fixed  
**Depends on:** [RFC-081](081-[fixed]-host-only-platform-nav-defaults.md), [RFC-084](../084-[open]-live-sports-host-feature-kit.md)  
**Area:** settings / shell / sync

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** components · **6 / 6** acceptance |
| **Current slice** | Two-layer flags shipped — availability vs rail |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R86-C01 | `addon_feature_iptv` / `addon_feature_live_matches` KV + migration from prior one-bit nav | ✅ |
| 2 | R86-C02 | Addons ON/OFF writes feature flags only (OFF strips rail as cleanup) | ✅ |
| 3 | R86-C03 | Features sole `visibleIds` writer; inventory from addon flags + pack destinations | ✅ |
| 4 | R86-C04 | Packs mark known hubs only — no first-seen auto-insert into `visibleIds` | ✅ |

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

## Summary

Split **feature availability** from **navbar visibility**.

| Layer | Meaning | Writes `navbar_config`? |
|-------|---------|-------------------------|
| **Addons** | IPTV / Live Sports system exists | No (OFF may strip tab as cleanup) |
| **Packs** | Hub feature exists | No |
| **Features** | Show on rail / order / star | Yes — only writer |

Default when a feature becomes available: listed in Features with rail **OFF** until the user enables it there.

### Related

- [Features settings](../../features/settings/navigation-bar.md)
- [Issue 224](../../issues/224-[open]-android-tv-addons-iptv-live-toggle-dead.md)
