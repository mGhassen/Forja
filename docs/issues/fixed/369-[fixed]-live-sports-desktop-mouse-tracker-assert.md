# 369 — Live Sports / IPTV desktop mouse_tracker assert flood

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · IPTV player · catalog dense list  
**Reported:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I369-T01 | Live Sports / IPTV player: volume hover via `ValueNotifier` (no parent `setState` on `MouseRegion`) | ✅ |
| 2 | I369-T02 | Defer chrome reveal + PiP hover `setState` past `MouseRegion.onHover` | ✅ |
| 3 | I369-T03 | Dense schedule list: defer hover notifier past mouse_tracker device update | ✅ |
| 4 | I369-T04 | Progressive Live Sports schedule paints coalesced to next frame | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I369-A01 | Desktop: open Live Sports, move mouse over list/cards while catalogs scrape — no `!_debugDuringDeviceUpdate` flood | ⬜ |
| 2 | I369-A02 | Desktop: Live Sports / IPTV player — hover volume + move to reveal chrome without mouse_tracker assert spam | ⬜ |

---

## Summary

Desktop debug flooded `mouse_tracker.dart` `!_debugDuringDeviceUpdate` in Live Sports. Parent `setState` from `MouseRegion.onEnter` / `onHover` (volume slider expand, chrome reveal, PiP chrome) rebuilt the same `MouseRegion` mid device update and cascaded. Progressive schedule `setState` under the cursor worsened hit-test churn.

**Root fix:** ValueNotifier / post-frame defer for hover chrome; coalesce progressive schedule paints to the next frame.
