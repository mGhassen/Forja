# 234 — macOS boot catalog feed JSC SIGSEGV

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Catalog · `EngineService.runCatalog` · macOS JSC · Home boot  
**Reported:** 2026-09-08

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I234-T01 | Catalog `feed`/`rail` EngineJS-first (stop blanket `preferFlutterJs`) | ✅ |
| 2 | I234-T02 | Serialize catalog flutter_js forks + settle-then-drop JSC VM after extract | ✅ |
| 3 | I234-T03 | Changelog — macOS boot no longer dies after Home feed | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I234-A01 | Manual macOS: cold launch → splash → Home paints — no Lost connection / Crash Reporter JSC SIGSEGV | ⬜ |

---

## Summary

**Symptom:** macOS Forja dies ~7s after launch once Home `feed` runs (`Lost connection to device`). Crash Reporter: `EXC_BAD_ACCESS` / SIGSEGV at `0x4` in `JSLockHolder` ← `JSValueToStringCopy` during `drainMicrotasks` after `JSEvaluateScript` on the main thread. Same class as [189](./189-[fixed]-engine-jsc-use-after-dispose-on-cancel.md) / [193](./193-[fixed]-nuvio-jsc-use-after-dispose-on-play.md).

**Root (before fix):** `runCatalog` forced flutter_js for every `feed`/`rail` (`preferFlutterJs`) so Live Sports could call `ctx.host.liveFeed.load`. Home TMDB feed does not need that bridge — boot prefetch + KitShell both forked main-thread JSC, then `dispose()` freed the VM while JSC still drained microtasks.

**Symptom fix:** EngineJS-first for all catalog actions (Live Sports still falls back when EngineJS has no `liveFeed`); serialize catalog flutter_js forks; always settle (pump + short delay) before dropping the JSC heap.

**Still open (broader):** [190](../190-[open]-forja-engine-parallel-jsc-crash.md) / RFC-064 — remaining flutter_js Engine paths off main-thread JSC.

Manual macOS boot smoke (`I234-A01`) still unverified in this turn.
