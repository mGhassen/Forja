# 527 — Windows PiP expand: black player + loading spinner

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Windows desktop PiP (`DesktopPipChannel` · player restore)  
**Reported:** 2026-11-02 (manual — expand float back to main)  
**Fixed:** 2026-11-02

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 2** acceptance (manual Windows) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Windows: enter desktop picture-in-picture (separate float), then Expand back into the main player → main window stays **black** with a **loading spinner/slider**. macOS Expand restores video.

## Root cause

`DesktopPipChannel::DestroyFloat` fire-and-forgot float `teardown`, then immediately reset the secondary `FlutterViewController` and `DestroyWindow`. Main Dart `await destroyFloat` returned before float media_kit dispose finished, then `restoreFromPip` opened a new Player over a half-dead float engine. macOS delays float engine shutdown (issue [489](489-[fixed]-desktop-pip-float-lifecycle-invalid-engine.md)), so Expand raced less.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I527-T01 | Windows `destroyFloat`: InvokeMethod `teardown` with result callback; keep float engine alive until Dart dispose returns | ✅ |
| 2 | I527-T02 | 3s timeout + hide float during wait; sync immediate kill for CreateFloat / destructor | ✅ |
| 3 | I527-T03 | Defer engine kill off MethodResult reply stack; guard timer with destroy generation (stale WM_TIMER) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I527-A01 | Windows: VOD PiP → Expand — video restores in main (no stuck black + spinner) | ⬜ |
| 2 | I527-A02 | Windows: IPTV / Live Sports PiP → Expand — same | ⬜ |

---

## Summary

**Symptom fix:** n/a  
**Root fix:** Windows `destroyFloat` completes only after float `teardown` (media_kit dispose) or 3s timeout, then destroys the float HWND on a deferred timer tick — so main `restoreFromPip` starts on a clean process.

## Related

- [430](../430-[open]-desktop-pip-placeholder-separate-float.md) · [RFC-121](../../rfc/121-[open]-desktop-pip-float-window.md)
- [489](489-[fixed]-desktop-pip-float-lifecycle-invalid-engine.md) (macOS float lifecycle)
