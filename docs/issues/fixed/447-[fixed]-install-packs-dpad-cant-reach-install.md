# 447 — Install packs D-pad cannot reach Install

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Settings → Forja Packs · Install packs checklist · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I447-T01 | Register Install as toolbar TvKitRow index 2; shrink itemCount when disabled | ✅ |
| 2 | I447-T02 | Disabled filled buttons paint-only on TV (no owned FocusNode) | ✅ |
| 3 | I447-T03 | ↑ from pack list prefers Install when a selection exists | ✅ |
| 4 | I447-T04 | TV filled primary CTA paints brand green on focus (no gray flat ring) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I447-A01 | ATV: check a pack → ↑ lands on Install → OK starts download; ← reaches Clear / Select all | ⬜ |

---

## Summary

On **Install packs**, after checking a pack, D-pad could not reach the **Install** button.

**Root:** Toolbar `TvKitRow` only registered Select all (0) and Clear (1). Install lived outside the graph (`ShellTvZone.settings`, no `tvItemIndex`). → from Clear relied on `requestFocus`, while a disabled Install still mounted an owned focus node that confused the toolbar. → at Clear’s edge could trap without landing on Install.

**Fix:** Install is toolbar index 2 when enabled; disabled filled buttons are paint-only on TV; ↑ from the list prefers Install once something is selected.
