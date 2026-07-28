# 130 — Android TV player D-pad stuck on Play (full-screen FocusScope)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Exo / IPTV / film player · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I130-T01 | `FocusableControl` / `ForjaInteractive`: call `focusInDirection` on the focused node, not the enclosing `FocusScope` | ✅ |
| 2 | I130-T02 | `CustomSeekbar` ↑/↓: same focused-node directional traversal | ✅ |
| 3 | I130-T03 | Widget test: → from Play reaches Rewind inside full-screen chrome `FocusScope` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I130-A01 | Android TV Exo / IPTV / film player: after chrome shows on Play, ←/→/↑/↓ move focus across transport + top bar (not stuck; keys no longer no-op) | ⬜ |

---

## Summary

On **Android TV**, player chrome often looked stuck: focus sat on **Play** (`exo-player-play`), Select still toggled play/pause, but D-pad arrows never moved focus. Logs showed `[TV-KEY] Arrow * focus=exo-player-play` with no `[TV-FOCUS]` change.

**Root cause:** `FocusableControl` (and siblings) called `FocusScope.of(context).focusInDirection(...)`. Player chrome wraps a **full-screen** `FocusScope` (`SizedBox.expand`). Directional search from that scope’s rect finds **no neighbors**, so traversal returns false. App-root `_ShellTvDirectionalFocusAction` then **swallows** ←/→ without moving focus — remote looks dead.

**Root fix:** Drive `focusInDirection` from the **focused control node** (same as Flutter’s `DirectionalFocusAction`, which uses `primaryFocus`).

## Related

- [110](110-[open]-android-tv-iptv-player-top-bar-dpad.md) — IPTV top-bar ←/→ across title gap
- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad parity
- [Player](../features/playback/player.md) · [IPTV Xtream](../features/live/iptv-xtream.md)
