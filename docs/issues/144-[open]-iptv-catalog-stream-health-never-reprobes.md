# 144 — IPTV catalog channel health never updates on re-check

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV catalog · live channel cards · in-player guide

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I144-T01 | Catalog lazy health: 2‑min TTL + stale-while-revalidate (keep last border until re-probe) | ✅ |
| 2 | I144-T02 | In-player channel guide: same TTL freshness gate | ✅ |
| 3 | I144-T03 | In-player guide: probe on TV paint-focus (`didUpdateWidget`), not MouseRegion-only | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I144-A01 | Hover/focus a live channel → green/red; wait >2 min → hover/focus again → border updates if alive/dead flipped | ⬜ |
| 2 | I144-A02 | Within 2 min, re-hover does not re-probe (no flicker / spam); guide rows match | ⬜ |
| 3 | I144-A03 | Android TV: ↑/↓ on in-player guide channel list shows green/red status after debounce | ⬜ |

---

## Summary

Live catalog cards probe on hover/focus and tint the border green/red. After the first result, `streamHealth.containsKey` skipped forever for the session — a later probe never refreshed the card even when the stream flipped.

**Root fix:** Same **2‑minute** freshness window as portal status dots. Stale entries stay painted until the new probe lands, then the border updates. In-player guide uses the same TTL.

**Follow-up (I144-T03):** Guide rows used paint-only D-pad focus with health probe wired only to `MouseRegion` — Android TV ↑/↓ never scheduled a check. Probe now runs when the focused channel row changes.

## Related

- [iptv-xtream](../features/live/iptv-xtream.md) — catalog live health
- Portal status TTL — `iptv_controller_browser.dart` `_portalHealthTtl`
