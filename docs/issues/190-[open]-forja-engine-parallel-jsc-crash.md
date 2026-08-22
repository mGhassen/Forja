# 190 — Forja Engine parallel JSC crash / UI-isolate starvation

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Sources → Forja · `EngineRuntime.fork` · macOS JSC · `crates/engine-js`

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** fix · **3 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I190-T01 | RFC-064 Rust QuickJS crate + STREAMCRYPTO + fetch bridges | ✅ |
| 2 | I190-T02 | `EngineAsyncJob.engineJsExtract` + Dart cutover with flutter_js fallback | ✅ |
| 3 | I190-T03 | Per-job cancel token (task-local) aborts Rust extract without stomping siblings | ✅ |
| 4 | I190-T04 | Manual: ≥3 chips including videasy — no Lost connection | ⬜ |
| 5 | I190-T05 | `runPluginIsolated`: cancel / gen bump must not fall through to `flutter_js` fork | ✅ |
| 6 | I190-T06 | Play closes Sources: always `EngineService.cancelPending` (stop scrapes); `cancelEngineJobs: false` only keeps magnet | ✅ |
| 7 | I190-T07 | `engine_jobs::cancel_kind(EngineJsExtract)` + FFI — abort Forja extracts without global `request()` / magnet kill | ✅ |
| 8 | I190-T08 | rust-js CryptoJS façade + `ctx.hop` (vidsrcsbs / multiembed path) | ✅ |
| 9 | I190-T09 | rust-js `needs_host` → Dart `EngineHostResolver` (no flutter_js re-run) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I190-A01 | Videasy alone still returns streams (Rust or fallback) | ✅ |
| 2 | I190-A02 | Videasy + VidLink + Goated concurrent — app stays up | ✅ |
| 3 | I190-A03 | Under All walk, videasy does not burn empty solely from peer cancel / UI-isolate contention | ✅ |
| 4 | I190-A04 | Play mid All-walk — scrapes stop; no cancel→`flutter_js` stampede; no Lost connection | ⬜ |

---

## Summary

**Symptom:** Selecting multiple Forja chips (even 3) while videasy runs → `Lost connection to device` after a peer finishes. Under All, videasy times out empty though alone it returns streams in ~6s. **Also:** Play while All walk runs → peers flip from `(rust-js)` to bare `[engine] X start` + `[ep] drop` then SIGSEGV. Skipping `cancelPending` on Play avoided the stampede but left scrapes running in the background.

**Root (JSC):** Parallel `flutter_js` forks on the UI isolate + dispose of finished forks while siblings pump (JSC). Not a pool-order bug.

**Root (play stampede, 2026-08-21):** Play called `_cancelActiveSourceFetch(cancelEngineJobs: false)` but still ran `EngineService.cancelPending()` → `_extractGeneration++`. In-flight `_runHttpPluginRustJs` returned `null` on gen mismatch; `runPluginIsolated` treated that as “unsupported” and forked N× `flutter_js` mid-mpv. Log signature: `(rust-js)` then after Play bare `start` + `[ep] drop`.

**Root (post Rust QuickJS):** `EngineJobs` attached every job to one process-global cancel slot (`JOB_TOKEN_GLOBAL`). Peer finish/`clear_job_token` and peer `attach` overwrote Videasy’s token mid-`/seed` fetch — empty under All, fine alone. NuvioMobile keeps cancel on the parent coroutine `Job` tree, not a shared global AbortSignal.

**Root fix:** [RFC-064](../rfc/064-[open]-rust-quickjs-engine-runtime.md) — QuickJS-in-Rust per extract on tokio + `scope_job_token` task-local cancel (NuvioMobile shape). Nuvio host scrapers unchanged. **Plus** never map cancel-null → `flutter_js`; Play aborts Forja extracts via kind-scoped cancel (not full `cancel_all` / ROOT `request()`).

**Shipped for I190-T03:** `utils::engine_cancel::scope_job_token` + `EngineJobs.submit` wraps each job; `engine-js` `native_fetch` / `extract` `select!` on that token only.

**Shipped for I190-T05 / T06 / T07:** `runPluginIsolated` gen gate; Play always `cancelPending` (scrapes stop); `cancel_kind(EngineJsExtract)` + `Engine.cancelEngineJsExtracts` so magnet resolve survives.
