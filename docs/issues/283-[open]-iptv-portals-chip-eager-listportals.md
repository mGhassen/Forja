# Issue 283: IPTV Portals chip eagerly runs listPortals on hub open

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV hub · Portals chrome · flutter_js catalog queue

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I283-T01 | Vault-only `PortalsHost.chipSummary` for closed Portals chip label | ✅ |
| 2 | I283-T02 | Chip watches `portalsChipSummaryProvider`; `listPortals` only when panel open | ✅ |
| 3 | I283-T03 | Invalidate chip summary on portal mutations / panel close | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I283-A01 | Open IPTV with panel closed — logs show `feed` flutter_js, **no** `listPortals` until Portals opens | ⬜ |
| 2 | I283-A02 | Closed chip still shows active portal label from vault | ⬜ |
| 3 | I283-A03 | Open Portals → inventory loads; select portal → chip label updates after close | ⬜ |

---

## Summary

Opening the IPTV hub painted the Portals chip, which `ref.watch`ed `portalsInventoryProvider` → pack `listPortals` on every visit. That contended with catalog `feed` on the serialized flutter_js mutex even when the user never opened the panel.

**Root fix:** chip label/hasPortal from vault (`iptv.portals` / `iptv.active`). Full `listPortals` only when the panel mounts / opens.
