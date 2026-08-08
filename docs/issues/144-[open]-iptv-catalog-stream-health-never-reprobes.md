# 144 — IPTV catalog channel health never updates on re-check

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** IPTV catalog · live channel cards · in-player guide

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I144-T01 | Catalog lazy health: 2‑min TTL + stale-while-revalidate (keep last border until re-probe) | ✅ |
| 2 | I144-T02 | In-player channel guide: same TTL freshness gate | ✅ |
| 3 | I144-T03 | In-player guide: probe on TV paint-focus (`didUpdateWidget`), not MouseRegion-only | ✅ |
| 4 | I144-T04 | Drop TTL skip — every hover/focus dwell re-probes; border/dot updates when alive/dead flips | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I144-A01 | Hover/focus a live channel → green; kill the feed → re-hover/focus same channel → border/dot turns red (no 2‑min wait) | ⬜ |
| 2 | I144-A02 | First-time check on a sibling channel still goes red/green correctly while a prior green card re-probes | ⬜ |
| 3 | I144-A03 | Android TV: ↑/↓ on in-player guide channel list shows green/red status after debounce; re-dwell updates if flipped | ⬜ |

---

## Summary

Live catalog cards probe on hover/focus and tint the border green/red. After the first result, `streamHealth.containsKey` skipped forever for the session — a later probe never refreshed the card even when the stream flipped.

**Root fix (T01–T03):** Same **2‑minute** freshness window as portal status dots. Stale entries stay painted until the new probe lands, then the border updates. In-player guide uses the same TTL. Guide rows probe on TV paint-focus.

**Follow-up (I144-T04):** TTL still left a green card stuck until expiry while first-time checks on other channels correctly went red after the portal died. Catalog + guide now **re-probe on every dwell** (350ms debounce, in-flight dedupe, TV `onlyThis` queue trim). Last color stays until the new result lands; `notifyListeners` / `setState` only when the value flips.

## Related

- [iptv-xtream](../features/live/iptv-xtream.md) — catalog live health
- Portal status TTL — `iptv_controller_browser.dart` `_portalHealthTtl` (unchanged — portals still use 2‑min cache)
