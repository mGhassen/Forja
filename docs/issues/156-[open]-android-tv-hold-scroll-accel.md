# 156 — Android TV hold ↑/↓ scroll acceleration

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** TV / IPTV / Sources / Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I156-T01 | Shared `ShellTvHoldAccel` stride curve (hold duration → step) | ✅ |
| 2 | I156-T02 | Wire stride into catalog coordinator (vertical rows + stream grid), linear menus, spatial `focusInDirection` | ✅ |
| 3 | I156-T03 | Portals jump-by-stride + in-player channel guide `_moveFocus` stride | ✅ |
| 4 | I156-T04 | Unit test for accel curve | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I156-A01 | Android TV: hold ↓ through Portals / categories / channels — stride increases after ~0.5s and keeps focus visible | ⬜ |
| 2 | I156-A02 | Android TV: hold ↓ through Sources (torrent) panel and Settings detail lists — same accel feel | ⬜ |
| 3 | I156-A03 | Android TV: category floating reorder still steps one group per ↑/↓ (no accel) | ⬜ |

---

## Summary

Long D-pad holds on Android TV only moved **one item per OS key-repeat**. For long IPTV lists (portals, categories, channels), Sources, and Settings, that felt slow.

**Fix:** `ShellTvHoldAccel` increases stride (2 → 3 → 5 → 8) after ~1.2s / 2.2s / 3.5s / 5s while the same ↑/↓ key is held. Catalog vertical rows / grids jump by stride; portals and the channel guide reuse their jump-to-index paths; spatial and linear focus paths multi-step. Category reorder mode still swallows repeats and moves one slot per press.
