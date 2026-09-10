# 268 — Android TV Settings Addons / Features: D-pad scroll stuck at top

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings → Addons · Features · D-pad scroll

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2/2** · A **0/2** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I268-T01 | `_nearestVerticalScrollable` skips zero-extent vertical nests so `shellTvEnsureVisibleItem` hits the page scroller | ✅ |
| 2 | I268-T02 | Widget test: outer `SingleChildScrollView` moves when focus ensureVisible runs under shrink-wrap `NeverScrollable` ListView | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I268-A01 | Android TV Settings → Features: ↓ through tabs scrolls the detail pane (focus + scrollbar leave the top) | ⬜ |
| 2 | I268-A02 | Android TV Settings → Addons: ↓ past the fold scrolls the list (Connected services / lower rows stay on-screen) | ⬜ |

---

## Summary

On **Android TV**, **Settings → Features** kept the detail scrollbar at the top while D-pad ↓ moved focus, and **Addons** would not scroll the lower rows into view.

**Root cause:** Addons / Features build a shrink-wrap `ListView` / `ReorderableListView` with `NeverScrollableScrollPhysics` inside `SettingsPageScaffold`’s `SingleChildScrollView`. `shellTvEnsureVisibleItem` took the nearest vertical `Scrollable` — the nest with `maxScrollExtent ≈ 0` — so `jumpTo` never moved the outer page scroller.

**Root fix:** Prefer a vertical scroller that can actually move (`maxScrollExtent > min`); fall back to the nearest vertical only when nothing overflows yet.

**Related:** [262](262-[fixed]-android-tv-forja-packs-last-pack-clipped.md) · [127](../127-[open]-android-tv-settings-detail-dpad.md)
