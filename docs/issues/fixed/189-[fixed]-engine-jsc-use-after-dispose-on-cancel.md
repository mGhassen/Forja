# 189 — Engine (Forja tab) JSC SIGSEGV on cancel / leave details

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `apps/forja/lib/shared/engine/runtime.dart`, `service.dart`  
**Reported:** 2026-08-20

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I189-T01 | Defer VM drop while `_activeExtract > 0` (same pattern as Nuvio) | ✅ |
| 2 | I189-T02 | Gate timer/fetch/hop/host callbacks with `_evalOn` (identical / `_deferredDrop`) | ✅ |
| 3 | I189-T03 | Track live forks; `EngineRuntime.abortAll()` aborts instance + forks | ✅ |
| 4 | I189-T04 | `EngineService.cancelPending` → `abortAll` (not instance-only) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I189-A01 | Cancel / leave details mid-Forja resolve does not dispose the live JSC heap under an in-flight extract pump | ✅ |
| 2 | I189-A02 | Manual macOS: Sources → Forja running → Cancel / Back — no SIGSEGV | ⬜ |

---

## Summary

macOS Crash Reporter for Forja `1.3.319`: `EXC_BAD_ACCESS` / SIGSEGV in JavaScriptCore (`JSLockHolder` ← `JSValueToStringCopy` during `drainMicrotasks` after `JSEvaluateScript`) on the main thread while Sources → Forja was resolving (e.g. after `vidfast done`). Same class as the Nuvio cancel race: evaluate on a disposed flutter_js context.

**Root cause:** `EngineService.cancelPending` only aborted `EngineRuntime.instance`. Sources Forja uses `runPluginIsolated` → `EngineRuntime.fork()` per plugin — forks kept running. Separately, `abortPendingWork` dropped the VM immediately even with `_activeExtract > 0`, while the extract pump still called `executePendingJob` / fetch resolve `evaluate` after `await` yields.

**Root fix:** Deferred VM drop until extract `finally`; `_evalOn` guards; `abortAll` for shared + forks; `cancelPending` wires to `abortAll`.

Manual macOS reproduce (I189-A02) still unverified in this turn.
