# 190 — Forja Engine parallel JSC crash / UI-isolate starvation

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Sources → Forja · `EngineRuntime.fork` · macOS JSC

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I190-T01 | RFC-064 Rust QuickJS crate + STREAMCRYPTO + fetch bridges | ✅ |
| 2 | I190-T02 | `EngineAsyncJob.engineJsExtract` + Dart cutover with flutter_js fallback | ✅ |
| 3 | I190-T03 | Cancel token aborts Rust extract | 🔄 |
| 4 | I190-T04 | Manual: ≥3 chips including videasy — no Lost connection | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I190-A01 | Videasy alone still returns streams (Rust or fallback) | ⬜ |
| 2 | I190-A02 | Videasy + VidLink + Goated concurrent — app stays up | ⬜ |
| 3 | I190-A03 | Under All walk, videasy does not burn 105s empty solely from UI-isolate contention | ⬜ |

---

## Summary

**Symptom:** Selecting multiple Forja chips (even 3) while videasy runs → `Lost connection to device` after a peer finishes. Under All, videasy times out at 105s with 0 streams though alone it returns ~9 streams in ~6s.

**Root:** Parallel `flutter_js` forks on the UI isolate + dispose of finished forks while siblings pump (JSC). Not a pool-order bug.

**Root fix:** [RFC-064](../rfc/064-[open]-rust-quickjs-engine-runtime.md) — QuickJS-in-Rust per extract on tokio (NuvioMobile shape). Nuvio host scrapers unchanged.
