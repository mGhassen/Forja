# 237 — Live Sports catalog + resolve parallel flutter_js JSC SIGSEGV

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · `EngineService` flutter_js · macOS JSC  
**Reported:** 2026-09-08

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I237-T01 | Global `_withFlutterJsFork` queue (catalog + live resolve + VOD fallback) | ✅ |
| 2 | I237-T02 | Skip nested flutter_js under hub `liveFeed.load` → `runLiveFeed` | ✅ |
| 3 | I237-T03 | Live Sports `layout`/`filters` EngineJS-first (only `feed`/`rail` need liveFeed) | ✅ |
| 4 | I237-T04 | Changelog — Live Sports load + resolve no longer kill macOS | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I237-A01 | Manual macOS: open Live Sports → schedule paints → tap resolve while catalogs load — no Lost connection / JSC SIGSEGV | ⬜ |

---

## Summary

**Symptom:** macOS Forja dies while Live Sports hub catalog is loading (`Lost connection to device`). Crash Reporter: `EXC_BAD_ACCESS` / SIGSEGV at a wild address in `JSLockHolder` ← `JSValueToStringCopy` during `drainMicrotasks` after `JSEvaluateScript` on the main thread. Log signature: `live-sports-hub … needs liveFeed — flutter_js`, then `live-watchfooty enginejs live resolve empty — flutter_js fallback`, then `deferred VM drop after settle`, then more hub flutter_js → crash.

**Root (before fix):** [234](./234-[fixed]-macos-boot-catalog-feed-jsc-crash.md) serialized **catalog** flutter_js only. Live resolve (`runLivePlugin`) and live catalog fallback (`runLiveFeed`) still forked separate main-thread JSC heaps. Opening Live Sports (hub feed holds flutter_js for `liveFeed.load`) while a match resolve falls back to flutter_js = two VMs → SIGSEGV. Nested `liveFeed` → `runLiveFeed` flutter_js would also deadlock if forced onto the same mutex.

**Symptom fix:** One flutter_js queue for catalog / live resolve / VOD extract fallback; settle delay after every dispose; nested `runLiveFeed` under an active flutter_js fork skips flutter_js (EngineJS-only); hub `layout`/`filters` no longer force flutter_js.

**Still open (broader):** [190](../190-[open]-forja-engine-parallel-jsc-crash.md) / RFC-064 — remaining flutter_js Engine paths off main-thread JSC; EngineJS liveFeed bridge would remove hub feed flutter_js entirely.

Manual macOS Live Sports smoke (`I237-A01`) still unverified in this turn.

**Follow-up (2026-09-09):** I237-T02’s `_flutterJsDepth > 0` skip was too broad — sibling `metaFeedCatalogProvider` scrapes returned empty while hub layout held flutter_js (log still showed `[Streamed] streams=N`). Narrowed in [251](251-[fixed]-live-sports-streamed-empty-nested-skip.md).
