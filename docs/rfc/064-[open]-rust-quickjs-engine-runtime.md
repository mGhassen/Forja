# RFC-064: Rust QuickJS Engine runtime (Forja Sources)

**Status:** open  
**Depends on:** [RFC-060](fixed/060-[fixed]-enginejs-sources-forja-tab.md)  
**Area:** `crates/engine-js`, `crates/ffi` EngineJobs, `apps/forja/lib/shared/engine/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 6** components · **5 / 11** acceptance |
| **Current slice** | CryptoJS + ctx.hop in rust-js; cheerio/host + scrypt PoW still open; manual QA pending |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R64-C01 | `crates/engine-js` — rquickjs `AsyncRuntime` per extract on tokio | ✅ |
| 2 | R64-C02 | Bridges: `fetch`, timers, `streamDecrypt`, `encodePipe` / `decodePipe`, `solvePow` / scrypt PoW | 🔄 |
| 3 | R64-C03 | `EngineAsyncJob.engineJsExtract` + per-job task-local cancel token | ✅ |
| 4 | R64-C04 | Dart `runPluginIsolated` prefers Rust JS; flutter_js fallback | ✅ |
| 5 | R64-C05 | cheerio / `ctx.host` parity (later) | ⏭️ |
| 6 | R64-C06 | CryptoJS façade (AES/digest/hmac) + `ctx.hop` nested extract | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R64-A01 | Unit: STREAMCRYPTO decrypt matches Dart golden | ✅ |
| 2 | R64-A02 | Unit: two concurrent `extract` jobs each get own QuickJS runtime | ✅ |
| 3 | R64-A03 | `videasy` HotD S1E1 via Rust JS returns streams (or empty) without UI-isolate flutter_js | ⬜ |
| 4 | R64-A04 | Sources → Forja All with ≥3 chips: no process death while videasy + peer run | ⬜ |
| 5 | R64-A05 | Cancel / leave details aborts in-flight Rust JS jobs (per-job token; peers unaffected) | ⬜ |
| 6 | R64-A06 | Plugins needing cheerio keep working via flutter_js fallback until C05 | ⬜ |
| 7 | R64-A07 | ENGINE_BOUNDARY: Nuvio stays host `flutter_js` (D3); only Forja Engine HTTP moves | ✅ |
| 8 | R64-A08 | Manual macOS: select videasy+vidlink+goated — no `Lost connection` | ⬜ |
| 9 | R64-A09 | Unit: parallel `scope_job_token` — sibling finish/cancel does not clear peer token | ✅ |
| 10 | R64-A10 | Unit: CryptoJS AES passphrase encrypt/decrypt round-trip in rust-js | ✅ |
| 11 | R64-A11 | Unit: `ctx.hop` nested extract returns hop plugin streams | ✅ |

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
- Cancel: per-job `CancellationToken` via `engine_cancel::scope_job_token` (task-local). Host cancel drains `EngineJobs` tokens + `request()` on ROOT — peers must not share one global attach slot.

### Related

- [Issue 190](../issues/190-[open]-forja-engine-parallel-jsc-crash.md)
- [189](../issues/fixed/189-[fixed]-engine-jsc-use-after-dispose-on-cancel.md) (dispose race — symptom; this RFC is root)
- NuvioMobile `PluginRuntime.executePlugin` + `JsRuntime(Dispatchers.Default)`
