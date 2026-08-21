# 190 — Forja Engine parallel JSC crash / UI-isolate starvation

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Sources → Forja · `EngineRuntime.fork` · macOS JSC · `crates/engine-js`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I190-T01 | RFC-064 Rust QuickJS crate + STREAMCRYPTO + fetch bridges | ✅ |
| 2 | I190-T02 | `EngineAsyncJob.engineJsExtract` + Dart cutover with flutter_js fallback | ✅ |
| 3 | I190-T03 | Per-job cancel token (task-local) aborts Rust extract without stomping siblings | ✅ |
| 4 | I190-T04 | Manual: ≥3 chips including videasy — no Lost connection | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I190-A01 | Videasy alone still returns streams (Rust or fallback) | ⬜ |
| 2 | I190-A02 | Videasy + VidLink + Goated concurrent — app stays up | ⬜ |
| 3 | I190-A03 | Under All walk, videasy does not burn empty solely from peer cancel / UI-isolate contention | ⬜ |

---

## Summary

**Symptom:** Selecting multiple Forja chips (even 3) while videasy runs → `Lost connection to device` after a peer finishes. Under All, videasy times out empty though alone it returns streams in ~6s.

**Root (JSC):** Parallel `flutter_js` forks on the UI isolate + dispose of finished forks while siblings pump (JSC). Not a pool-order bug.

**Root (post Rust QuickJS):** `EngineJobs` attached every job to one process-global cancel slot (`JOB_TOKEN_GLOBAL`). Peer finish/`clear_job_token` and peer `attach` overwrote Videasy’s token mid-`/seed` fetch — empty under All, fine alone. NuvioMobile keeps cancel on the parent coroutine `Job` tree, not a shared global AbortSignal.

**Root fix:** [RFC-064](../rfc/064-[open]-rust-quickjs-engine-runtime.md) — QuickJS-in-Rust per extract on tokio + `scope_job_token` task-local cancel (NuvioMobile shape). Nuvio host scrapers unchanged.

**Shipped for I190-T03:** `utils::engine_cancel::scope_job_token` + `EngineJobs.submit` wraps each job; `engine-js` `native_fetch` / `extract` `select!` on that token only.
