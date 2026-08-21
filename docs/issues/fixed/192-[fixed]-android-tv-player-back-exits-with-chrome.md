# 192 — Android TV player Back exits while chrome is showing

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · player Back · `PlayerBackExitGate` · `ShellTvFocusCoordinator`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I192-T01 | After a chrome-hide stay, swallow HW + didPopRoute twins for the full back debounce window (do not re-run exit ladder) | ✅ |
| 2 | I192-T02 | Widen `PlayerBackExitGate` stay twin to 400ms; tests cover late (~150ms) twin must not exit | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I192-A01 | Unit/widget: hide chrome stay + Back at ~150ms keeps player; Back after debounce exits | ✅ |
| 2 | I192-A02 | Android TV: chrome visible → one remote Back hides chrome only; second Back leaves player (manual) | ⬜ |

---

## Summary

One leanback Back is delivered twice (`HardwareKeyboard` + `didPopRoute`). Hide-chrome stay armed exit (`setArmed(true)`). Twins were only swallowed for **80ms** while `_backStepPending` skipped the 400ms debounce — a twin arriving after 80ms saw chrome already down + armed and **popped the player on the same physical press**.

**Root fix:** while `_backStepPending`, swallow Back for the full debounce window without calling `tryFocusBackStay` again; stay twin window in the gate matches (400ms).
