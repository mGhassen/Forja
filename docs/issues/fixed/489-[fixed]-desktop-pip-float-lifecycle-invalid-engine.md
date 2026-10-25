# 489 — Desktop PiP float: Invalid engine handle on flutter/lifecycle

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** macOS desktop PiP (`DesktopPipChannel.swift`)  
**Reported:** 2026-10-25 (Cmd-Tab / background while Live player; console spam)  
**Fixed:** 2026-10-25

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Backgrounding Forja on macOS (Cmd-Tab / hide) after desktop PiP float create/teardown logged:

`FlutterEngineSendPlatformMessage` → `kInvalidArguments` / `Invalid engine handle`  
`Failed to send message to Flutter engine on channel 'flutter/lifecycle'`

Main Dart kept running. Console noise only (not a hard crash).

## Root cause

`FlutterEngine` registers with `FlutterAppDelegate` as a lifecycle delegate on init. `shutDownEngine` nulls the embedder `_engine` handle but **does not** unregister — removal is only in `dealloc`.

`DesktopPipChannel.destroyFloat` delayed `shutDownEngine` by 0.4s while keeping the ObjC engine alive. After shutdown (or while plugins still retained the object), AppKit resign/occlusion still forwarded lifecycle → `setApplicationState` → `flutter/lifecycle` on a null embedder handle.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I489-T01 | `removeApplicationLifecycleDelegate(engine)` before `shutDownEngine` in `destroyFloat` | ✅ |
| 2 | I489-T02 | Cancel pending shutdown work on re-entrant destroy/create | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I489-A01 | Enter desktop PiP, Cmd-Tab away/back — no `Invalid engine handle` / `flutter/lifecycle` spam | ⬜ |
| 2 | I489-A02 | Leave PiP then background — same, clean console | ⬜ |

---

## Summary

**Symptom fix:** n/a  
**Root fix:** unregister the float `FlutterEngine` from `FlutterAppLifecycleProvider` before `shutDownEngine`, then shut down on the next main turn (FVC held until then). Cancel any prior pending shutdown when destroy races with create.

**Related:** [367](../367-[workaround]-macos-cmd-tab-frame-freeze.md) (occlusion resume workaround — separate)
