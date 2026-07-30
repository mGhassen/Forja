# 130 — Android TV player D-pad stuck on Play (full-screen FocusScope)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Exo / IPTV / film player · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I130-T01 | `FocusableControl` / `ForjaInteractive`: call `focusInDirection` on the focused node, not the enclosing `FocusScope` | ✅ |
| 2 | I130-T02 | `CustomSeekbar` ↑/↓: same focused-node directional traversal | ✅ |
| 3 | I130-T03 | Widget test: → from Play reaches Rewind inside full-screen chrome `FocusScope` | ✅ |
| 4 | I130-T04 | Exo TV transport: explicit Play ↔ ±10s ↔ right-cluster edges (parity with MediaKit) | ✅ |
| 5 | I130-T05 | Chrome auto-hide: ping activity on D-pad while chrome visible + defer hide while chrome has focus | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I130-A01 | Android TV Exo / IPTV / film player: after chrome shows on Play, ←/→/↑/↓ move focus across transport + top bar (not stuck; chrome does not hide mid-D-pad) | ⬜ |

---

## Summary

On **Android TV**, player chrome often looked stuck: focus sat on **Play** (`exo-player-play`), Select still toggled play/pause, but D-pad arrows never moved focus. Logs showed `[TV-KEY] Arrow * focus=exo-player-play` with no `[TV-FOCUS]` change.

**Root cause (spatial):** `FocusableControl` (and siblings) called `FocusScope.of(context).focusInDirection(...)`. Player chrome wraps a **full-screen** `FocusScope` (`SizedBox.expand`). Directional search from that scope’s rect finds **no neighbors**, so traversal returns false. App-root `_ShellTvDirectionalFocusAction` then **swallows** ←/→ without moving focus — remote looks dead.

**Root fix (spatial):** Drive `focusInDirection` from the **focused control node** (same as Flutter’s `DirectionalFocusAction`, which uses `primaryFocus`).

**Root cause (Exo + hide mid-nav):** Exo transport relied on spatial only (MediaKit already had explicit `onRightEdge` / `onLeftEdge`). Chrome auto-hide also fired while D-pad moved because `FocusableControl` consumes arrows before `PlayerTvKeyScope.onKeyEvent`, so `onControlsActivity` never reset the timer. Hide + `ExcludeFocus` then left focus on Play with dead ←/→.

**Root fix (Exo + hide):** Explicit transport edges on Exo; hardware-keyboard activity ping while chrome is visible; defer hide while `playerTvChromeHasFocus`.

## Related

- [110](110-[open]-android-tv-iptv-player-top-bar-dpad.md) — IPTV top-bar ←/→ across title gap
- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad parity
- [Player](../features/playback/player.md) · [IPTV Xtream](../features/live/iptv-xtream.md)
