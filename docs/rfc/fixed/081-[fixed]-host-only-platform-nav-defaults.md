# RFC-081: Host-only platform nav defaults

**Status:** fixed  
**Depends on:** [RFC-028](../028-[draft]-adaptive-shell-profiles.md) (R28-A28 superseded for new installs), [RFC-080](../080-[open]-post-login-packs-onboarding.md)  
**Area:** shell / plugins / settings

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** components · **6 / 6** acceptance |
| **Current slice** | Empty fresh-install nav — no Addons on until user enables |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R81-C01 | `PlatformDefaults.defaultNavIds` host-owned only (`iptv`) | ✅ |
| 2 | R81-C02 | Hub tabs enter rail via `ensureNavIdsKnown` / pack `nav` — not baked into platform defaults or `PluginNavRegistry.seedBuiltIns` | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R81-A01 | Fresh install navbar seeds `['iptv']` on every profile | ✅ |
| 2 | R81-A02 | `_baseAllNavIds` has no pack hub tab ids; hubs register via `registerExtraNavIds` | ✅ |
| 3 | R81-A03 | First-seen hub from an enabled pack auto-shows; user hide stays hidden | ✅ |
| 4 | R81-A04 | Legacy shell migrations still rewrite untouched old defaults to the pre-081 pack-seeded list — do not strip hubs on upgrade | ✅ |

---

## Acceptance (empty Addons default)

Supersedes R81-A01 for **new** installs only — existing seeded layouts unchanged.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 5 | R81-A05 | Fresh install navbar seeds `[]` — IPTV / Live Sports off until Addons or Features | ✅ |
| 6 | R81-A06 | Hub recovery / first-seen never force-on Addons-gated core tabs (`iptv`, `live_matches`) | ✅ |

---

## Summary

`PlatformDefaults` and `PluginNavRegistry.seedBuiltIns` must not name catalog hub packs (`anime`, `asian_drama`, `live-sports-hub`, …). Fresh installs start with **no** feature tabs — Settings only. Host-core **IPTV** and **Live Sports** turn on via **Settings → Addons** (or Features). Hub tabs appear when packs contribute `nav` and `ensureNavIdsKnown` first-sees them (same contract as Features auto-on).

**Supersedes for new installs:** RFC-028 R28-A28 (baked Home / Anime / Asian Drama / Live / My List into platform defaults). That row stays frozen ✅ as historical; this RFC is the new source of truth. R81-A01 (`['iptv']`) stays frozen ✅ as the first host-only slice; R81-A05 is the empty-addons follow-up.

### Goals

- Pack-agnostic host defaults
- Fresh guest / post-login onboarding: empty rail until Addons / Features / packs
- Existing custom / untouched pack-seeded layouts unchanged by upgrade migrations

### Related

- [Navigation](../features/getting-started/navigation.md)
- [Features settings](../features/settings/navigation-bar.md)
- [RFC-084](../084-[open]-live-sports-host-feature-kit.md) — **exception:** `live_matches` is host core (Addons) like `iptv`, not a pack-gated VOD hub. Still **not** in `PlatformDefaults.defaultNavIds` (visibility via Addons / Features).
