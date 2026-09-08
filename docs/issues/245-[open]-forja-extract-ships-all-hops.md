# 245 — Forja extract ships every hop into every plugin job

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Forja Sources · EngineJS · `plugins/providers` · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** fix · **1 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I245-T01 | Manifest `hops` on HTTP plugins; omit = no hop payload | ✅ |
| 2 | I245-T02 | EngineJS + flutter_js attach only declared hops (`*` = all active) | ✅ |
| 3 | I245-T03 | Concrete hop ids only where proven in source; kisskh/dynamic scrapers empty until known hosts | ✅ |
| 4 | I245-T04 | Optional later: specific hop ids / Rust process hop registry (no per-job code) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I245-A01 | Unit: empty / `*` / listed `hops` selection | ✅ |
| 2 | I245-A02 | Log: videasy (and peers without `hops`) start with `hops=0` | ⬜ |
| 3 | I245-A03 | ATV player Sources → Forja All: no SIGQUIT / Lost connection mid-walk | ⬜ |

---

## Summary

**Symptom:** Android TV player Sources → Forja All ANR’d (`signal 3` / Lost connection) while many `(enginejs)` jobs ran. Every start logged `hops=21`.

**Root:** Dart `_runHttpPluginRustJs` loaded **all** hop plugin scripts into **every** EngineJS job — including plugins that never call `ctx.hop` (videasy, moviebox, …). No provider→hop link in the pack manifest.

**Fix:** Pack declares `hops: ["hop-megaup", …]` (or the full hop id list for dynamic scrapers). Omit / `[]` → attach nothing. Host selects via `hopPluginsDeclaredFor`. `*` still works as “all active hops” but providers pack now lists concrete ids.

**Related:** [RFC-064](../rfc/064-[open]-rust-quickjs-engine-runtime.md) R64-C08 · [issue 190](190-[open]-forja-engine-parallel-jsc-crash.md)
