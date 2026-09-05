# Issue 220: Live Sports Addons ON but no navbar tab

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Settings Addons · shell nav · Live Sports

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **3 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

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
| 3 | I220-A03 | Hub pack enabled still overrides layout via CatalogShell | ✅ |

---

## Summary

Addons Live Sports only wrote `live_matches` into `navbar_config`. The rail filtered with `PluginNavRegistry.isContributed`, which required a hub pack. Root fix: host core tab + kit standard layout ([RFC-084](../rfc/084-[open]-live-sports-host-feature-kit.md)).

Shipped in code; rename to `[fixed]` after manual QA of Addons → list → panel → play.
