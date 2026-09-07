# Issue 220: Live Sports Addons ON but no navbar tab

**Status:** canceled  
**Priority:** P1  
**Severity:** High  
**Area:** Settings Addons · shell nav · Live Sports

## Status at a glance

| | |
|--|--|
| **Progress** | **Canceled** — wrong fix; see [RFC-087](../rfc/fixed/087-[fixed]-live-sports-pack-only.md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Why canceled

Root cause (Addons ON required a hub pack for `isContributed`) was “fixed” by baking a **host core** Live Sports tab ([RFC-084](../rfc/canceled/084-[canceled]-live-sports-host-feature-kit.md)). Product rule is pack-only: no hub pack → no Live Sports tab. Capability settings stay under Addons; chrome comes from hub packs.

Historical fix/acceptance rows frozen below.

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I220-T01 | Add `live_matches` to `coreShellNavIds` + core destination/builder (kit host-default) | ✅ |
| 2 | I220-T02 | Exclude core ids from `syncActiveHubNavIds` strip when hub pack off | ✅ |
| 3 | I220-T03 | Standard UX: match list + right streams panel (no details push) | ✅ |
| 4 | I220-T04 | Docs / changelog / RFC-084 acceptance | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I220-A01 | Addons → Live Sports ON with no hub pack → rail shows Live Sports | ✅ |
| 2 | I220-A02 | Tap match → right panel Providers/Live TV (not full details page) | ✅ |
| 3 | I220-A03 | Hub pack enabled still overrides layout via KitShell | ✅ |

---

## Summary

Superseded by RFC-087 pack-only Live Sports.
