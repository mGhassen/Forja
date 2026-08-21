# RFC-064: Rust QuickJS Engine runtime (Forja Sources)

**Status:** open  
**Depends on:** [RFC-060](fixed/060-[fixed]-enginejs-sources-forja-tab.md)  
**Area:** `crates/engine-js`, `crates/ffi` EngineJobs, `apps/forja/lib/shared/engine/`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 5** components · **2 / 8** acceptance |
| **Current slice** | Rust QuickJS + EngineJobs wired; Sources cutover with flutter_js fallback |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R64-C01 | `crates/engine-js` — rquickjs `AsyncRuntime` per extract on tokio | ✅ |
| 2 | R64-C02 | Bridges: `fetch`, timers, `streamDecrypt`, `encodePipe` / `decodePipe`, `solvePow` / scrypt PoW | 🔄 |
| 3 | R64-C03 | `EngineAsyncJob.engineJsExtract` + cancel token | ✅ |
| 4 | R64-C04 | Dart `runPluginIsolated` prefers Rust JS; flutter_js fallback | ✅ |
| 5 | R64-C05 | cheerio / `ctx.hop` / `ctx.host` parity (later) | ⏭️ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R64-A01 | Unit: STREAMCRYPTO decrypt matches Dart golden | ✅ |
| 2 | R64-A02 | Unit: two concurrent `extract` jobs each get own QuickJS runtime | ✅ |
| 3 | R64-A03 | `videasy` HotD S1E1 via Rust JS returns streams (or empty) without UI-isolate flutter_js | ⬜ |
| 4 | R64-A04 | Sources → Forja All with ≥3 chips: no process death while videasy + peer run | ⬜ |
| 5 | R64-A05 | Cancel / leave details aborts in-flight Rust JS jobs | ⬜ |
| 6 | R64-A06 | Plugins needing cheerio/hop keep working via flutter_js fallback until C05 | ⬜ |
| 7 | R64-A07 | ENGINE_BOUNDARY: Nuvio stays host `flutter_js` (D3); only Forja Engine HTTP moves | ✅ |
| 8 | R64-A08 | Manual macOS: select videasy+vidlink+goated — no `Lost connection` | ⬜ |

---

## Summary

### Problem

Sources → Forja runs up to 10 `EngineRuntime.fork()` heaps on the **Flutter UI isolate** (`flutter_js`). Parallel pumps contend; disposing one fork while another extracts can SIGSEGV (macOS JSC). Alone, videasy finishes in ~6s; under the pool it hits the 105s timeout empty. NuvioMobile avoids this with **fresh QuickJS per scraper on `Dispatchers.Default`**.

### Goals

1. Run Forja Engine HTTP `extract(ctx)` in **Rust QuickJS**, one runtime per job, on the existing tokio `EngineJobs` pool (true parallel, off UI).
2. Keep plugin JS assets (`assets/providers/*.js`) unchanged.
3. Do **not** move Nuvio community scrapers (still host C4).
4. Gradual cutover: Rust first for fetch/crypto plugins; flutter_js fallback when Rust returns unsupported / missing bridge.

### Non-goals (this RFC)

- Replacing Nuvio `flutter_js`
- Porting WebView `ctx.host` sniff into Rust
- Deleting Dart `EngineRuntime` until parity is complete

### Contracts

- Job payload: `{ plugin_id, code, ctx, timeout_ms, allow_host_fallback, hop_scripts? }`
- Result: `{ streams: [...] }` or `{ error, unsupported?: true }` for fallback
- Cancel: existing `engine_cancel` job token

### Related

- [Issue 190](../issues/190-[open]-forja-engine-parallel-jsc-crash.md)
- [189](../issues/fixed/189-[fixed]-engine-jsc-use-after-dispose-on-cancel.md) (dispose race — symptom; this RFC is root)
- NuvioMobile `PluginRuntime.executePlugin` + `JsRuntime(Dispatchers.Default)`
