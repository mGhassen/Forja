# 130 — Android TV player D-pad stuck on Play (full-screen FocusScope)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Exo / IPTV / film player · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 2** acceptance |

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
| 6 | I130-T06 | `PlayerStreamPickerButton`: accept `onRightEdge` / `onUpEdge` / `onDownEdge` and forward them to `FocusableControl` (it only took `onLeftEdge`, so → off the source button had no wired neighbour) | ✅ |
| 7 | I130-T07 | Complete the TV transport chain on both engines — Exo source → episodes/audio + ↑ to seekbar; MediaKit right cluster (sources, stream, episodes, audio, subs, quality, settings) and prev/next episode get focus nodes with ←/→/↑ edges | ✅ |
| 8 | I130-T08 | Widget test: → from the stream picker reaches the next transport control inside the full-screen chrome scope | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I130-A01 | Android TV Exo / IPTV / film player: after chrome shows on Play, ←/→/↑/↓ move focus across transport + top bar (not stuck; chrome does not hide mid-D-pad) | ⬜ |
| 2 | I130-A02 | Android TV movie player: → from Play walks every bottom control up to Settings — the source button no longer bounces focus back to Play; ↑ from any right-cluster control returns to the seekbar | ⬜ |

---

## Summary

On **Android TV**, player chrome often looked stuck: focus sat on **Play** (`exo-player-play`), Select still toggled play/pause, but D-pad arrows never moved focus. Logs showed `[TV-KEY] Arrow * focus=exo-player-play` with no `[TV-FOCUS]` change.

**Root cause (spatial):** `FocusableControl` (and siblings) called `FocusScope.of(context).focusInDirection(...)`. Player chrome wraps a **full-screen** `FocusScope` (`SizedBox.expand`). Directional search from that scope’s rect finds **no neighbors**, so traversal returns false. App-root `_ShellTvDirectionalFocusAction` then **swallows** ←/→ without moving focus — remote looks dead.

**Root fix (spatial):** Drive `focusInDirection` from the **focused control node** (same as Flutter’s `DirectionalFocusAction`, which uses `primaryFocus`).

**Root cause (Exo + hide mid-nav):** Exo transport relied on spatial only (MediaKit already had explicit `onRightEdge` / `onLeftEdge`). Chrome auto-hide also fired while D-pad moved because `FocusableControl` consumes arrows before `PlayerTvKeyScope.onKeyEvent`, so `onControlsActivity` never reset the timer. Hide + `ExcludeFocus` then left focus on Play with dead ←/→.

**Root fix (Exo + hide):** Explicit transport edges on Exo; hardware-keyboard activity ping while chrome is visible; defer hide while `playerTvChromeHasFocus`.

### Follow-up — source button broke the chain (T06 · T07)

→ still died on the **source / stream picker** in the movie player. `PlayerStreamPickerButton` exposed only `onLeftEdge`, so → from it had no wired neighbour and fell back to spatial traversal, which the shell deliberately no-ops for ←/→ (`_ShellTvDirectionalFocusAction`). The MediaKit TV row was worse: everything after the picker (episodes, audio, subtitles, quality, settings) had neither a focus node nor edges, and → from Forward 10s skipped the prev/next episode buttons entirely.

**Fix:** the picker now takes right/up/down edges, and both TV transport rows wire every control to its neighbours — no control in the bottom bar depends on geometry for ←/→ any more.

**Not verified on device.** The exact spatial-traversal failure (focus landing back on Play rather than simply not moving) was not reproduced under a debugger — `I130-A02` remains the on-device gate.

## Related

- [110](110-[open]-android-tv-iptv-player-top-bar-dpad.md) — IPTV top-bar ←/→ across title gap
- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad parity
- [Player](../features/playback/player.md) · [IPTV Xtream](../features/live/iptv-xtream.md)
