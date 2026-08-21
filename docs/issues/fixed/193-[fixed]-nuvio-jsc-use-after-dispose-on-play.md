# 193 — Nuvio JSC SIGSEGV on play (deferred drop gap)

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `apps/forja/lib/shared/nuvio/nuvio_runtime.dart`, `apps/forja/lib/shared/engine/runtime.dart`  
**Reported:** 2026-08-21

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I193-T01 | Nuvio: `_evalOn` for timer / fetch resolve; refuse schedule when `_deferredDrop` | ✅ |
| 2 | I193-T02 | Nuvio: defer `dispose` / VM drop while `_activeGetStreams > 0` | ✅ |
| 3 | I193-T03 | Nuvio: pump loop aborts when `_deferredDrop` | ✅ |
| 4 | I193-T04 | Engine: `TimerSchedule` refuses while `_deferredDrop` / not accepting | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I193-A01 | Play / cancel mid-Nuvio resolve does not dispose the live JSC heap under an in-flight pump | ✅ |
| 2 | I193-A02 | Manual macOS: Sources → Nuvio/Forja running → Play stream — no SIGSEGV | ⬜ |

---

## Summary

macOS Crash Reporter for Forja `1.4.0` (Dabaghin): `EXC_BAD_ACCESS` / SIGSEGV in JavaScriptCore (`JSLockHolder` ← `JSValueToStringCopy` during `drainMicrotasks` after `JSEvaluateScript`) on the main thread while a movie was playing (~2 min after launch). MediaKit/mpv was active; Rust subtitle FFI ran on DartWorkers. Same class as [189](./189-[fixed]-engine-jsc-use-after-dispose-on-cancel.md): evaluate on a disposed flutter_js context.

**Root cause (before fix):** Engine already deferred VM drop + `_evalOn` (189). Nuvio still evaluated timer/fetch callbacks and dropped the runtime while `getStreams` pumps could resume after `abortPendingWork` / play-path cancel — null VM → read at `0x4`.

**Root fix:** Mirror Engine on Nuvio — deferred drop, `_evalOn`, deferred TimerSchedule, pump abort on `_deferredDrop`. Engine TimerSchedule also refuses when deferred.

**Still open (broader):** [190](../190-[open]-forja-engine-parallel-jsc-crash.md) / RFC-064 — migrate remaining flutter_js Engine path off main-thread JSC.

Manual macOS play reproduce (I193-A02) still unverified in this turn.
